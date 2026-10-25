import CoreData
import Foundation
import OSLog
import Observation
import UIKit

/// Connects the offline-first store to the Trama platform (licence + encrypted sync).
///
/// Core Data stays the source of truth. When the iPad is linked to a licence, service writes
/// are queued in the outbox (`saveTracked`), pushed to `/sync/push`, and server changes are
/// pulled from `/sync/pull` with a persisted cursor. Without a licence nothing here runs and
/// the app behaves exactly as a local-only install.
@MainActor
@Observable
final class SyncEngine {
    /// The company this iPad is linked to.
    struct Account: Codable, Equatable {
        var email: String
        var tenantID: String
        var tenantName: String
    }

    private(set) var account: Account?
    private(set) var licence: LicenceInfo?
    private(set) var isSyncing = false
    private(set) var lastSyncAt: Date?
    private(set) var lastError: String?
    private(set) var pendingCount = 0
    /// False when the refresh token is gone (signed out, revoked, expired): sign in online again.
    private(set) var hasSession = false

    var isLinked: Bool { account != nil }
    var isReadOnly: Bool { isLinked && licence?.writable == false }
    var needsReconnect: Bool { isLinked && !hasSession }

    @ObservationIgnored let api: APIClient
    @ObservationIgnored private let persistence: PersistenceController
    @ObservationIgnored private let session: Session
    @ObservationIgnored private let toasts: ToastCenter?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let secrets: SecretStore
    @ObservationIgnored private let enabled: Bool
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var scheduled: Task<Void, Never>?
    @ObservationIgnored private var syncAgain = false
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private let log = Logger(subsystem: "com.nevutech.ipb", category: "sync")

    /// Changes per push request; the server accepts 500 and Vercel caps bodies at 4.5 MB.
    static let maxBatchCount = 200
    static let maxBatchBytes = 3_000_000
    /// Records per pull page.
    @ObservationIgnored var pullLimit = 500

    private enum Keys {
        static let account = "sync.account"
        static let licence = "sync.licence"
        static let cursor = "sync.cursor"
        static let lastSyncAt = "sync.lastSyncAt"
        static let deviceID = "sync.deviceID"
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    init(
        persistence: PersistenceController, session: Session, toasts: ToastCenter?, api: APIClient? = nil,
        secrets: SecretStore = KeychainStore(), defaults: UserDefaults = .standard, enabled: Bool = true,
        debounce: Duration = .seconds(3)
    ) {
        self.persistence = persistence
        self.session = session
        self.toasts = toasts
        self.secrets = secrets
        self.defaults = defaults
        self.enabled = enabled
        self.debounce = debounce
        self.api = api ?? APIClient(secrets: secrets)
        account = Self.load(Account.self, Keys.account, defaults)
        licence = Self.load(LicenceInfo.self, Keys.licence, defaults)
        lastSyncAt = defaults.object(forKey: Keys.lastSyncAt) as? Date
        hasSession = self.api.hasRefreshToken
        applyTrackingFlags()
        refreshPendingCount()
        observer = NotificationCenter.default.addObserver(forName: .syncOutboxChanged, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, (note.object as? NSManagedObjectContext) === self.context else { return }
                self.refreshPendingCount()
                self.requestSync(after: self.debounce)
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var cursor: Int64 {
        get { Int64(defaults.integer(forKey: Keys.cursor)) }
        set { defaults.set(Int(newValue), forKey: Keys.cursor) }
    }

    /// Persistent per-install device id (Keychain), sent with every login for the seat count.
    var device: DeviceInfo {
        let id =
            secrets.string(for: Keys.deviceID)
            ?? {
                let id = UUID().uuidString
                secrets.set(id, for: Keys.deviceID)
                return id
            }()
        return DeviceInfo(id: id, name: UIDevice.current.name)
    }

    // MARK: Licence activation / sign in

    /// What to do with data already on this iPad when it joins a licence.
    enum LocalData { case replace, keepAndUpload }

    /// "Conectar con mi licencia": signs in against the platform, links the iPad to the company,
    /// stores the signed-in user locally (so offline login keeps working) and runs a first sync.
    func connect(email: String, password: String, localData: LocalData = .keepAndUpload) async throws {
        guard enabled else { throw APIError.offline }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, !password.isEmpty else { throw AuthError.emptyFields }
        let auth = try await api.login(email: email, password: password, device: device)

        if localData == .replace {
            try persistence.eraseAll()
            cursor = 0
        } else if let previous = account, previous.tenantID != auth.tenant.id {
            // A different company: start its history from scratch.
            try SyncOutbox.clear(in: context)
            cursor = 0
        }
        let firstLink = account?.tenantID != auth.tenant.id
        link(Account(email: email, tenantID: auth.tenant.id, tenantName: auth.tenant.name), licence: auth.licence)
        if (defaults.string(forKey: Brand.companyKey) ?? "").isEmpty { defaults.set(auth.tenant.name, forKey: Brand.companyKey) }

        let user = try adoptServerUser(auth.user)
        session.adopt(user)
        if firstLink, localData == .keepAndUpload, user.role == .admin {
            try SyncOutbox.enqueueAll(in: context)
            refreshPendingCount()
        }
        await sync()
    }

    /// Login screen: local credentials first (works offline). When linked, the cloud session is
    /// re-bound to this user in the background; when the local check fails, the platform is tried
    /// (a user created or a password reset on the web that hasn't synced yet).
    func signIn(email: String, password: String) async throws {
        do {
            try session.signIn(email: email, password: password)
            if isLinked, enabled, account?.email != normalized(email) || !hasSession {
                Task { try? await self.rebind(email: email, password: password) }
            }
        } catch let local {
            guard isLinked, enabled else { throw local }
            do {
                // Stores the server's copy of the user (with its password hash) and adopts it.
                try await rebind(email: email, password: password)
            } catch let api as APIError {
                if case .offline = api { throw local }
                throw api
            }
            if !session.isSignedIn { try session.signIn(email: email, password: password) }
        }
    }

    /// Closes the session on this iPad and revokes the device token on the server.
    func signOut() async {
        session.signOut()
        guard isLinked else { return }
        await api.logout()
        hasSession = false
    }

    /// Unlinks the iPad from the company. Local data stays; the outbox and cursor are dropped.
    func disconnect() async {
        await api.logout()
        hasSession = false
        try? SyncOutbox.clear(in: context)
        account = nil
        licence = nil
        lastSyncAt = nil
        lastError = nil
        cursor = 0
        defaults.removeObject(forKey: Keys.account)
        defaults.removeObject(forKey: Keys.licence)
        defaults.removeObject(forKey: Keys.lastSyncAt)
        applyTrackingFlags()
        refreshPendingCount()
    }

    /// Admin action: queue every local record for upload (e.g. after a legacy import).
    func uploadAllLocalData() async throws {
        guard isLinked else { return }
        try SyncOutbox.enqueueAll(in: context)
        refreshPendingCount()
        await sync()
    }

    // MARK: Sync

    /// Debounced trigger (local writes, foreground, reconnect).
    func requestSync(after delay: Duration = .zero) {
        guard enabled, isLinked, hasSession else { return }
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Push the outbox, then pull until the server has nothing newer than the cursor.
    func sync() async {
        guard enabled, isLinked, hasSession else { return }
        if isSyncing {
            syncAgain = true
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
            refreshPendingCount()
        }
        repeat {
            syncAgain = false
            do {
                do {
                    try await push()
                } catch APIError.server(_, "licence_inactive", _) {
                    // Read-only licence: local changes stay queued; reading still works.
                }
                try await pull()
                lastSyncAt = .now
                defaults.set(lastSyncAt, forKey: Keys.lastSyncAt)
                lastError = nil
            } catch let error as APIError {
                if case .sessionExpired = error { hasSession = false }
                lastError = error.localizedDescription
                log.error("sync failed: \(error.code ?? "?", privacy: .public)")
                return
            } catch {
                lastError = error.localizedDescription
                log.error("sync failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        } while syncAgain
    }

    func push() async throws {
        let entries = SyncOutbox.entries(in: context)
        guard !entries.isEmpty else { return }

        var batch: [(entry: SyncOutboxEntry, changedAt: Date?, json: Data)] = []
        var bytes = 0
        var problems: [String] = []

        func flush() async throws {
            guard !batch.isEmpty else { return }
            let sent = batch
            batch = []
            bytes = 0
            var body = Data(#"{"changes":["#.utf8)
            body.append(Data(sent.map(\.json).joined(separator: Data(",".utf8))))
            body.append(Data("]}".utf8))
            let response: PushResponse
            do {
                response = try await api.push(body: body)
            } catch APIError.server(let status, _, let message) where status == 402 {
                // Licence expired or suspended: keep the outbox, switch to read-only.
                setLicence(writable: false)
                throw APIError.server(status: status, code: "licence_inactive", message: message)
            }
            if let licence = response.licence { updateLicence(licence) }
            try handle(response, sent: sent.map { ($0.entry, $0.changedAt) }, problems: &problems)
        }

        for entry in entries {
            guard let raw = entry.entityName, let entity = SyncEntity(rawValue: raw), let id = entry.recordID else {
                context.delete(entry)
                continue
            }
            var change = OutgoingChange(entity: entity, id: id, updatedAt: entry.changedAt ?? .now, deleted: entry.tombstone, data: nil)
            if !entry.tombstone {
                let request = NSFetchRequest<NSManagedObject>(entityName: entity.entityName)
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                guard let object = try context.fetch(request).first, let payload = RecordPayload(object) else {
                    context.delete(entry)  // the record vanished without a tombstone (e.g. erased)
                    continue
                }
                change.data = payload
            }
            let json = try change.wireData()
            if !batch.isEmpty, batch.count >= Self.maxBatchCount || bytes + json.count > Self.maxBatchBytes { try await flush() }
            batch.append((entry, entry.changedAt, json))
            bytes += json.count
        }
        try await flush()
        try context.saveIfNeeded()

        if let first = problems.first {
            let others = problems.count - 1
            let message: LocalizedStringResource =
                others > 0
                ? "No se sincronizó un cambio: \(first) (y \(others) más)"
                : "No se sincronizó un cambio: \(first)"
            toasts?.show(message, style: .error)
        }
    }

    private func handle(
        _ response: PushResponse, sent: [(entry: SyncOutboxEntry, changedAt: Date?)], problems: inout [String]
    ) throws {
        func key(_ entity: String, _ id: UUID) -> String { "\(entity)/\(id.uuidString.lowercased())" }
        let byKey = Dictionary(
            sent.compactMap { item -> (String, (entry: SyncOutboxEntry, changedAt: Date?))? in
                guard let entity = item.entry.entityName, let id = item.entry.recordID else { return nil }
                return (key(entity, id), item)
            }, uniquingKeysWith: { first, _ in first })

        /// Drops an entry unless the record changed again while the request was in flight.
        func settle(_ item: (entry: SyncOutboxEntry, changedAt: Date?)?) {
            guard let item, !item.entry.isDeleted, item.entry.changedAt == item.changedAt else { return }
            context.delete(item.entry)
        }

        for applied in response.applied { settle(byKey[key(applied.entity, applied.id)]) }
        var adopt: [ServerChange] = []
        for rejection in response.rejected {
            let item = byKey[key(rejection.entity, rejection.id)]
            switch rejection.reason {
            case "stale":
                // The server has a newer version: adopt it (last writer wins).
                if let entry = item?.entry, !entry.isDeleted { context.delete(entry) }
                if let server = rejection.server { adopt.append(server) }
            default:
                // forbidden / limit / invalid / conflict: retrying won't help; tell the user.
                settle(item)
                problems.append(rejection.message)
            }
        }
        context.processPendingChanges()
        if !adopt.isEmpty { try SyncApplier.apply(adopt, in: context) }
        try context.saveIfNeeded()
    }

    func pull() async throws {
        var cursor = self.cursor
        var latest: [String: ServerChange] = [:]
        var page: PullResponse
        repeat {
            page = try await api.pull(cursor: cursor, limit: pullLimit)
            for change in page.changes {
                let key = "\(change.entity?.rawValue ?? "?")/\(change.id.uuidString)"
                if let existing = latest[key], existing.version > change.version { continue }
                latest[key] = change
            }
            if let licence = page.licence { updateLicence(licence) }
            cursor = max(cursor, page.cursor)
        } while page.hasMore && !page.changes.isEmpty

        if !latest.isEmpty {
            try SyncApplier.apply(Array(latest.values), in: context)
            reloadSession()
        }
        self.cursor = cursor
    }

    // MARK: State

    private func link(_ account: Account, licence: LicenceInfo) {
        self.account = account
        hasSession = api.hasRefreshToken
        Self.save(account, Keys.account, defaults)
        updateLicence(licence)
    }

    private func updateLicence(_ licence: LicenceInfo) {
        let wasWritable = self.licence?.writable ?? true
        self.licence = licence
        Self.save(licence, Keys.licence, defaults)
        applyTrackingFlags()
        if wasWritable, !licence.writable {
            let message: LocalizedStringResource =
                licence.status == "suspended"
                ? "Tu licencia está suspendida: los datos quedan en solo lectura."
                : "Tu licencia está vencida: los datos quedan en solo lectura."
            toasts?.show(message, style: .info)
        }
    }

    private func setLicence(writable: Bool) {
        var copy = licence ?? LicenceInfo(plan: "", status: "expired", expiresAt: nil, writable: writable)
        copy.writable = writable
        updateLicence(copy)
    }

    private func applyTrackingFlags() {
        context.isSyncTracking = enabled && isLinked
        context.isSyncReadOnly = isReadOnly
    }

    private func refreshPendingCount() { pendingCount = isLinked ? SyncOutbox.count(in: context) : 0 }

    /// After a pull: the signed-in user may have been edited, deactivated or deleted.
    private func reloadSession() {
        if let user = session.user, !user.isDeleted, user.managedObjectContext != nil, user.isActive {
            session.adopt(user)
        } else {
            session.restore()
        }
    }

    private func rebind(email: String, password: String) async throws {
        let auth = try await api.login(email: normalized(email), password: password, device: device)
        guard let account, auth.tenant.id == account.tenantID else {
            await api.logout()
            hasSession = false
            throw APIError.server(
                status: 409, code: "tenant_mismatch",
                message: String(
                    localized: "Ese usuario pertenece a otra empresa. Desconecta la licencia en Ajustes para cambiar de empresa."))
        }
        link(Account(email: normalized(email), tenantID: auth.tenant.id, tenantName: auth.tenant.name), licence: auth.licence)
        let user = try adoptServerUser(auth.user)
        if session.user == nil || session.user?.objectID == user.objectID { session.adopt(user) }
        await sync()
    }

    /// Stores (or updates) the signed-in user exactly as the server has it, including the
    /// password hash, so the next sign in works offline.
    @discardableResult
    private func adoptServerUser(_ dto: AppUserDTO) throws -> AppUser {
        guard let id = dto.id else { throw APIError.invalidResponse }
        let change = ServerChange(entity: .users, id: id, updatedAt: dto.updatedAt ?? .now, deleted: false, data: .user(dto))
        if let pending = SyncOutbox.entry(.users, id: id, in: context) { context.delete(pending) }
        try SyncApplier.apply([change], in: context)
        guard let user = context.fetchAll(AppUser.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first else {
            throw APIError.invalidResponse
        }
        return user
    }

    private func normalized(_ email: String) -> String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String, _ defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? BackupService.decoder.decode(type, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T, _ key: String, _ defaults: UserDefaults) {
        defaults.set(try? BackupService.encoder.encode(value), forKey: key)
    }
}
