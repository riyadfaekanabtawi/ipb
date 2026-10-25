import CoreData
import Foundation
import Testing
import UIKit

@testable import Trama

private func fetch<T: NSManagedObject>(_ type: T.Type, _ id: UUID, in context: NSManagedObjectContext) -> T? {
    context.fetchAll(type, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first
}

private func json(_ data: Data) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

// MARK: - Payloads

@MainActor
@Suite("Sync payloads use the backup DTO encoding")
struct SyncPayloadTests {
    @Test func outgoingChangeMatchesBackupDTOAndRoundTrips() throws {
        let source = PersistenceController(inMemory: true)
        let ctx = source.viewContext
        let catalog = CatalogService(context: ctx)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { $0.fill(CGRect(x: 0, y: 0, width: 2, height: 2)) }
        let client = try catalog.saveClient(nil, name: "Moda Norte", address: "Monterrey", contacts: [ContactDraft(name: "Luz", email: "luz@norte.mx")])
        let style = try catalog.saveStyle(nil, name: "Falda lápiz", imageData: image)
        let order = try ProductionService(context: ctx, author: "Ana").createOrder(
            code: "C-1", list: "L-1", garment: "Falda", quantity: 120, unitPrice: 55.5, client: client, style: style,
            internalDate: Date(timeIntervalSince1970: 1_760_000_000.123), clientDate: nil, notes: nil)

        // Same keys and values as the backup file entry for the same record.
        let change = OutgoingChange(entity: .orders, id: order.id!, updatedAt: order.updatedAt!, deleted: false, data: RecordPayload(order))
        let wire = try json(BackupService.encoder.encode(change))
        #expect(wire["entity"] as? String == "orders")
        #expect(wire["deleted"] as? Bool == false)
        let data = try #require(wire["data"] as? [String: Any])
        let backup = try json(BackupService.export(context: ctx))
        let backupOrder = try #require((backup["orders"] as? [[String: Any]])?.first)
        #expect(NSDictionary(dictionary: data).isEqual(to: backupOrder))
        #expect(data["clientID"] as? String == client.id!.uuidString)

        // On the wire every UUID is lowercase (the server's ciphertext AAD is case-sensitive);
        // everything else is byte-for-byte the backup DTO.
        let pushed = try json(change.wireData())
        #expect(pushed["id"] as? String == order.id!.uuidString.lowercased())
        let pushedData = try #require(pushed["data"] as? [String: Any])
        #expect(pushedData["id"] as? String == order.id!.uuidString.lowercased())
        #expect(pushedData["clientID"] as? String == client.id!.uuidString.lowercased())
        #expect(pushedData["styleID"] as? String == style.id!.uuidString.lowercased())
        #expect(NSDictionary(dictionary: pushedData).isEqual(to: OutgoingChange.lowercasingUUIDs(backupOrder)))
        #expect(pushedData["code"] as? String == "C-1")
        #expect((data["internalDate"] as? String)?.hasSuffix(".123Z") == true)  // ISO-8601 with milliseconds

        let styleWire = try json(BackupService.encoder.encode(RecordPayload(style)))
        #expect(styleWire["imageData"] as? String == image.base64EncodedString())

        // Decode as the server would send it back (lowercase ids) and apply into another store.
        var serverJSON = wire
        serverJSON["id"] = order.id!.uuidString.lowercased()
        serverJSON["version"] = 7
        let decoded = try BackupService.decoder.decode(ServerChange.self, from: JSONSerialization.data(withJSONObject: serverJSON))
        #expect(decoded.entity == .orders)
        #expect(decoded.id == order.id)
        #expect(decoded.version == 7)

        let target = PersistenceController(inMemory: true)
        let parents = [
            ServerChange(entity: .clients, id: client.id!, updatedAt: client.updatedAt!, deleted: false, data: RecordPayload(client)),
            ServerChange(entity: .styles, id: style.id!, updatedAt: style.updatedAt!, deleted: false, data: RecordPayload(style)),
        ]
        try SyncApplier.apply([decoded] + parents, in: target.viewContext)
        let copy = try #require(fetch(CutOrder.self, order.id!, in: target.viewContext))
        #expect(copy.code == "C-1")
        #expect(copy.quantity == 120)
        #expect(copy.unitPrice == 55.5)
        #expect(copy.editedBy == "Ana")
        #expect(abs(copy.internalDate!.timeIntervalSince(order.internalDate!)) < 0.001)
        #expect(copy.client?.id == client.id)
        #expect(copy.style?.imageData == image)
    }

    @Test func unknownEntitiesAndTombstonesDecode() throws {
        let raw = """
            {"changes":[
              {"entity":"widgets","id":"9b2b8e0e-6c5c-4a43-8f43-0a0d6c3b9d10","updatedAt":"2026-10-25T10:00:00.000Z","deleted":false,"data":{"x":1},"version":1},
              {"entity":"plants","id":"9b2b8e0e-6c5c-4a43-8f43-0a0d6c3b9d11","updatedAt":"2026-10-25T10:00:00Z","deleted":true,"data":null,"version":2}
            ],"cursor":2,"hasMore":false,"licence":{"plan":"planta","status":"active","expiresAt":"2027-01-01T00:00:00.000Z","writable":true}}
            """
        let page = try BackupService.decoder.decode(PullResponse.self, from: Data(raw.utf8))
        #expect(page.changes.count == 2)
        #expect(page.changes[0].entity == nil)
        #expect(page.changes[1].entity == .plants)
        #expect(page.changes[1].deleted)
        #expect(page.changes[1].data == nil)
        #expect(page.licence?.writable == true)
    }
}

// MARK: - Outbox

@MainActor
@Suite("Outbox: service writes are queued only while linked")
struct SyncOutboxTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }

    private func pending() -> [String: Bool] {
        Dictionary(
            SyncOutbox.entries(in: context).map { ("\($0.entityName!)/\($0.recordID!.uuidString)", $0.tombstone) },
            uniquingKeysWith: { a, _ in a })
    }

    @Test func localOnlyModeNeverQueues() throws {
        _ = try CatalogService(context: context).savePlant(nil, name: "Planta Sur", maxCapacity: 100_000)
        #expect(SyncOutbox.count(in: context) == 0)
    }

    @Test func productionAndCatalogWritesAreQueuedWithTombstones() throws {
        context.isSyncTracking = true
        let catalog = CatalogService(context: context)
        let service = ProductionService(context: context, author: "Ana")
        let plant = try catalog.savePlant(nil, name: "Planta Norte", maxCapacity: 1_000_000)
        let contactID = UUID()
        let client = try catalog.saveClient(nil, name: "Cliente", address: "", contacts: [ContactDraft(id: contactID, name: "Eva")])
        #expect(pending()["plants/\(plant.id!.uuidString)"] == false)
        #expect(pending()["clients/\(client.id!.uuidString)"] == false)
        #expect(pending()["contacts/\(contactID.uuidString)"] == false)

        try SyncOutbox.clear(in: context)
        // Linking the order to the client only touches the client's to-many side: not queued.
        let order = try service.createOrder(
            code: "C-9", list: "L", garment: "Blusa", quantity: 100, unitPrice: 10, client: client, style: nil,
            internalDate: nil, clientDate: nil, notes: nil)
        #expect(pending().keys.sorted() == ["orders/\(order.id!.uuidString)"])

        let before = order.updatedAt!
        let assignment = try service.assign(order: order, to: plant, quantity: 40, date: .now)
        #expect(pending()["assignments/\(assignment.id!.uuidString)"] == false)
        #expect(order.updatedAt! >= before)

        let entry = try #require(SyncOutbox.entry(.assignments, id: assignment.id!, in: context))
        #expect(entry.changedAt == assignment.updatedAt)  // the push carries the record's updatedAt

        let assignmentID = assignment.id!
        try service.unassign(assignment)
        #expect(pending()["assignments/\(assignmentID.uuidString)"] == true)  // coalesced into a tombstone
        #expect(SyncOutbox.entries(in: context).filter { $0.recordID == assignmentID }.count == 1)

        // Cascades become tombstones too.
        try catalog.saveClient(client, name: "Cliente", address: "", contacts: [])
        #expect(pending()["contacts/\(contactID.uuidString)"] == true)
    }

    @Test func readOnlyLicenceRefusesWritesAndRollsBack() throws {
        context.isSyncTracking = true
        context.isSyncReadOnly = true
        #expect(throws: SyncWriteError.readOnly) {
            try CatalogService(context: context).savePlant(nil, name: "Planta", maxCapacity: 10)
        }
        #expect(context.count(Plant.self) == 0)
        #expect(SyncOutbox.count(in: context) == 0)
    }

    @Test func enqueueAllQueuesEveryRecord() throws {
        DemoSeeder.seed(into: context)
        context.isSyncTracking = true
        let total = try SyncEntity.allCases.reduce(0) { $0 + (try context.count(for: NSFetchRequest<NSManagedObject>(entityName: $1.entityName))) }
        _ = try SyncOutbox.enqueueAll(in: context)
        #expect(SyncOutbox.count(in: context) == total)
    }
}

// MARK: - Applying pulled changes

@MainActor
@Suite("Apply pull: upsert, delete, last writer wins")
struct SyncApplyTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }
    let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    private func plant(_ id: UUID, name: String, at date: Date) -> ServerChange {
        ServerChange(
            entity: .plants, id: id, updatedAt: date, deleted: false,
            data: .plant(PlantDTO(id: id, name: name, maxCapacity: 500_000, createdAt: date, updatedAt: date)))
    }

    @Test func upsertsResolveRelationshipsRegardlessOfOrder() throws {
        let plantID = UUID(), orderID = UUID(), assignmentID = UUID(), reportID = UUID()
        let changes = [
            ServerChange(
                entity: .reports, id: reportID, updatedAt: t0, deleted: false,
                data: .report(ProductionReportDTO(id: reportID, kindRaw: "envio", shipmentNumber: "7", shippedQuantity: 30, assignmentID: assignmentID))),
            ServerChange(
                entity: .assignments, id: assignmentID, updatedAt: t0, deleted: false,
                data: .assignment(AssignmentDTO(id: assignmentID, quantity: 50, unitPrice: 10, orderID: orderID, plantID: plantID))),
            ServerChange(entity: .orders, id: orderID, updatedAt: t0, deleted: false, data: .order(CutOrderDTO(id: orderID, code: "C-77", quantity: 50))),
            plant(plantID, name: "Planta Norte", at: t0),
        ]
        let result = try SyncApplier.apply(changes, in: context)
        #expect(result.upserted == 4)
        let assignment = try #require(fetch(Assignment.self, assignmentID, in: context))
        #expect(assignment.order?.code == "C-77")
        #expect(assignment.plant?.name == "Planta Norte")
        #expect(assignment.cuttingStatus == .waiting)
        #expect(assignment.metrics.shipped == 30)
        #expect(SyncOutbox.count(in: context) == 0)  // applied changes never echo into the outbox

        // Update in place: same object, new values.
        try SyncApplier.apply([plant(plantID, name: "Planta Norte 2", at: t0.addingTimeInterval(60))], in: context)
        #expect(context.count(Plant.self) == 1)
        #expect(fetch(Plant.self, plantID, in: context)?.name == "Planta Norte 2")
    }

    @Test func tombstonesDeleteButRespectDenyRules() throws {
        let plantID = UUID(), orderID = UUID(), assignmentID = UUID()
        try SyncApplier.apply(
            [
                plant(plantID, name: "Planta", at: t0),
                ServerChange(entity: .orders, id: orderID, updatedAt: t0, deleted: false, data: .order(CutOrderDTO(id: orderID, quantity: 5))),
                ServerChange(
                    entity: .assignments, id: assignmentID, updatedAt: t0, deleted: false,
                    data: .assignment(AssignmentDTO(id: assignmentID, quantity: 5, orderID: orderID, plantID: plantID))),
            ], in: context)

        // The plant still has an assignment here: its delete is held back.
        var result = try SyncApplier.apply([ServerChange(entity: .plants, id: plantID, updatedAt: t0, deleted: true, data: nil)], in: context)
        #expect(result.blocked == 1)
        #expect(fetch(Plant.self, plantID, in: context) != nil)

        // Deleting the order cascades its assignment, so the plant can go in the same batch.
        result = try SyncApplier.apply(
            [
                ServerChange(entity: .plants, id: plantID, updatedAt: t0, deleted: true, data: nil),
                ServerChange(entity: .orders, id: orderID, updatedAt: t0, deleted: true, data: nil),
            ], in: context)
        #expect(result.deleted == 2)
        #expect(context.count(Plant.self) == 0)
        #expect(context.count(Assignment.self) == 0)
    }

    @Test func lastWriterWinsAgainstPendingLocalChanges() throws {
        let id = UUID()
        try SyncApplier.apply([plant(id, name: "Servidor", at: t0)], in: context)
        context.isSyncTracking = true
        let local = try #require(fetch(Plant.self, id, in: context))
        try CatalogService(context: context).savePlant(local, name: "Local", maxCapacity: 500_000)
        let localTime = try #require(local.updatedAt)

        // An older server version loses: the local edit stays queued for push.
        var result = try SyncApplier.apply([plant(id, name: "Viejo", at: localTime.addingTimeInterval(-60))], in: context)
        #expect(result.keptLocal == 1)
        #expect(local.name == "Local")
        #expect(SyncOutbox.entry(.plants, id: id, in: context) != nil)

        // A newer server version wins and drops the pending entry.
        result = try SyncApplier.apply([plant(id, name: "Nuevo", at: localTime.addingTimeInterval(60))], in: context)
        #expect(result.upserted == 1)
        #expect(local.name == "Nuevo")
        #expect(SyncOutbox.entry(.plants, id: id, in: context) == nil)
    }

    @Test func pulledUserAdoptsLocalAccountWithSameEmail() throws {
        let local = try Session.createUser(
            firstName: "Ana", lastName: "", email: "ana@empresa.mx", phone: "", password: "secreto1", role: .admin, plant: nil,
            avatar: nil, in: context)
        let serverID = UUID()
        let salt = PasswordHasher.makeSalt()
        try SyncApplier.apply(
            [
                ServerChange(
                    entity: .users, id: serverID, updatedAt: t0, deleted: false,
                    data: .user(
                        AppUserDTO(
                            id: serverID, email: "ana@empresa.mx", firstName: "Ana", roleRaw: Role.admin.rawValue, isActive: true,
                            passwordHash: PasswordHasher.hash("nube123", salt: salt), passwordSalt: salt)))
            ], in: context)
        #expect(context.count(AppUser.self) == 1)
        #expect(local.id == serverID)
        // Offline login works with the synced PBKDF2 hash.
        #expect(PasswordHasher.verify("nube123", hash: local.passwordHash, salt: local.passwordSalt))
    }
}

// MARK: - Engine against a fake platform

@MainActor
@Suite("SyncEngine against the platform API")
struct SyncEngineTests {
    let persistence = PersistenceController(inMemory: true)
    let platform = FakePlatform()
    let secrets = MemorySecretStore()
    let defaults: UserDefaults
    let session: Session
    let toasts = ToastCenter()
    let engine: SyncEngine

    init() {
        let suite = "trama.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        session = Session(context: persistence.viewContext, defaults: defaults)
        let api = APIClient(baseURL: URL(string: "https://fake.trama.test/api")!, session: MockURLProtocol.register(platform), secrets: secrets)
        engine = SyncEngine(
            persistence: persistence, session: session, toasts: toasts, api: api, secrets: secrets, defaults: defaults,
            debounce: .seconds(3600))
    }

    var context: NSManagedObjectContext { persistence.viewContext }

    private func connect() async throws {
        try await engine.connect(email: platform.userEmail, password: platform.password)
    }

    @Test func connectLinksStoresSecretsAndPullsAllPages() async throws {
        let plantID = UUID(), orderID = UUID(), assignmentID = UUID()
        let t = Date(timeIntervalSince1970: 1_760_000_000)
        // The assignment's version is older than the order's latest version (order edited later).
        platform.seed("plants", id: plantID, updatedAt: t, data: ["name": "Planta Norte", "maxCapacity": 900_000])
        platform.seed("assignments", id: assignmentID, updatedAt: t, data: ["quantity": 10, "unitPrice": 5, "orderID": orderID.uuidString, "plantID": plantID.uuidString])
        platform.seed("orders", id: orderID, updatedAt: t, data: ["code": "C-1", "quantity": 10, "unitPrice": 5])
        engine.pullLimit = 2

        try await connect()

        let login = try #require(platform.calls(to: "auth/login").first?.json)
        let device = try #require(login["device"] as? [String: Any])
        #expect(device["platform"] as? String == "ios")
        #expect(device["id"] as? String == secrets.string(for: "sync.deviceID"))
        #expect(secrets.string(for: APIClient.refreshTokenKey) == platform.refreshToken)
        #expect(defaults.string(forKey: APIClient.refreshTokenKey) == nil)  // never in UserDefaults

        #expect(engine.isLinked)
        #expect(engine.account?.tenantName == "Textiles Nube")
        #expect(session.user?.email == platform.userEmail)
        #expect(platform.calls(to: "sync/pull").count == 2)
        #expect(engine.cursor == platform.version)
        #expect(context.isSyncTracking)
        let assignment = try #require(fetch(Assignment.self, assignmentID, in: context))
        #expect(assignment.order?.code == "C-1")
        #expect(assignment.plant?.name == "Planta Norte")

        // Offline sign in with the synced hash.
        session.signOut()
        try session.signIn(email: platform.userEmail, password: platform.password)
        #expect(session.isSignedIn)
    }

    @Test func loginErrorsCarryTheServerMessage() async throws {
        await #expect(throws: APIError.server(status: 401, code: "bad_credentials", message: "Correo o contraseña incorrectos.")) {
            try await engine.connect(email: platform.userEmail, password: "nope")
        }
        #expect(!engine.isLinked)
    }

    @Test func pushSendsOutboxAndClearsApplied() async throws {
        try await connect()
        let plant = try CatalogService(context: context).savePlant(nil, name: "Planta Sur", maxCapacity: 250_000)
        #expect(SyncOutbox.count(in: context) == 1)

        await engine.sync()

        #expect(engine.lastError == nil)
        #expect(SyncOutbox.count(in: context) == 0)
        let row = try #require(platform.row("plants", plant.id!))
        let data = try #require(row["data"] as? [String: Any])
        #expect(data["name"] as? String == "Planta Sur")
        #expect(data["maxCapacity"] as? Double == 250_000)
        #expect(engine.lastSyncAt != nil)
    }

    @Test func localWritesTriggerADebouncedSync() async throws {
        let api = APIClient(baseURL: URL(string: "https://fake.trama.test/api")!, session: MockURLProtocol.register(platform), secrets: secrets)
        let quick = SyncEngine(
            persistence: persistence, session: session, toasts: toasts, api: api, secrets: secrets, defaults: defaults,
            debounce: .milliseconds(50))
        try await quick.connect(email: platform.userEmail, password: platform.password)
        let plant = try CatalogService(context: context).savePlant(nil, name: "Planta Rápida", maxCapacity: 1)
        for _ in 0..<100 where platform.row("plants", plant.id!) == nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(platform.row("plants", plant.id!) != nil)
    }

    @Test func staleRejectionAdoptsTheServerCopy() async throws {
        let id = UUID()
        let future = Date().addingTimeInterval(3_600)
        platform.seed("plants", id: id, updatedAt: future, data: ["name": "Servidor", "maxCapacity": 1_000, "updatedAt": platform.iso(future)])
        try await connect()
        let plant = try #require(fetch(Plant.self, id, in: context))

        // Edited locally "now", but the server's copy is newer: the push is rejected as stale.
        try CatalogService(context: context).savePlant(plant, name: "Local", maxCapacity: 2_000)
        // Skip the pull so only the rejection can bring the server copy back.
        try await engine.push()

        #expect(plant.name == "Servidor")
        #expect(plant.maxCapacity == 1_000)
        #expect(SyncOutbox.count(in: context) == 0)
    }

    @Test func forbiddenRejectionIsDroppedAndSurfaced() async throws {
        try await connect()
        platform.forbiddenEntities = ["clients"]
        _ = try CatalogService(context: context).saveClient(nil, name: "Cliente Prohibido", address: "", contacts: [])
        await engine.sync()
        #expect(SyncOutbox.count(in: context) == 0)
        #expect(toasts.current?.style == .error)
        #expect(toasts.current?.message.contains("Tu puesto no permite este cambio.") == true)
    }

    @Test func expiredAccessTokenIsRefreshedOnceAndRetried() async throws {
        try await connect()
        let oldRefresh = secrets.string(for: APIClient.refreshTokenKey)
        platform.accessToken = "rotated-elsewhere"  // the in-memory token is now rejected with 401
        await engine.sync()
        #expect(engine.lastError == nil)
        #expect(platform.calls(to: "auth/refresh").count == 1)
        #expect(secrets.string(for: APIClient.refreshTokenKey) != oldRefresh)  // rotated
        #expect(platform.calls(to: "sync/pull").last?.authorization == "Bearer \(platform.accessToken)")
    }

    @Test func revokedRefreshTokenPausesSync() async throws {
        try await connect()
        platform.accessToken = "rotated-elsewhere"
        platform.refreshToken = "revoked-by-admin"
        await engine.sync()
        #expect(engine.needsReconnect)
        #expect(secrets.string(for: APIClient.refreshTokenKey) == nil)
        #expect(engine.lastError == "Tu sesión expiró. Vuelve a iniciar sesión.")
    }

    @Test func signOutRevokesTheDeviceSession() async throws {
        try await connect()
        let token = platform.accessToken
        await engine.signOut()
        #expect(platform.calls(to: "auth/logout").first?.authorization == "Bearer \(token)")
        #expect(platform.refreshToken == "revoked")
        #expect(secrets.string(for: APIClient.refreshTokenKey) == nil)
        #expect(!session.isSignedIn)
        #expect(engine.isLinked)  // the company link and data stay
    }

    @Test func expiredLicenceIsReadOnly() async throws {
        try await connect()
        platform.writable = false
        await engine.sync()
        #expect(engine.isReadOnly)
        #expect(context.isSyncReadOnly)
        #expect(throws: SyncWriteError.readOnly) {
            try CatalogService(context: context).savePlant(nil, name: "Planta", maxCapacity: 10)
        }
    }

    @Test func offlineKeepsChangesQueued() async throws {
        try await connect()
        _ = try CatalogService(context: context).savePlant(nil, name: "Sin red", maxCapacity: 10)
        platform.offline = true
        await engine.sync()
        #expect(SyncOutbox.count(in: context) == 1)
        #expect(engine.lastError == APIError.offline.errorDescription)
        platform.offline = false
        await engine.sync()
        #expect(SyncOutbox.count(in: context) == 0)
    }
}

// MARK: - Model migration

@Suite("Model v1 → v2 lightweight migration")
struct SyncMigrationTests {
    @Test func versionOneStoreOpensWithTheOutboxModel() throws {
        let bundle = Bundle(for: PersistenceController.self)
        let v1URL = try #require(bundle.url(forResource: "Trama", withExtension: "mom", subdirectory: "Trama.momd"))
        let v1 = try #require(NSManagedObjectModel(contentsOf: v1URL))
        #expect(v1.entitiesByName["SyncOutboxEntry"] == nil)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Trama.sqlite")

        let id = UUID()
        do {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1)
            let store = try coordinator.addPersistentStore(
                type: .sqlite, at: url, options: [NSPersistentHistoryTrackingKey: true as NSNumber])
            let old = NSManagedObjectContext(.mainQueue)
            old.persistentStoreCoordinator = coordinator
            let plant = NSEntityDescription.insertNewObject(forEntityName: "Plant", into: old)
            plant.setValue(id, forKey: "id")
            plant.setValue("Planta v1", forKey: "name")
            try old.save()
            try coordinator.remove(store)
        }

        let migrated = PersistenceController(storeURL: url)
        let ctx = migrated.viewContext
        let plant = try #require(fetch(Plant.self, id, in: ctx))
        #expect(plant.name == "Planta v1")
        ctx.isSyncTracking = true
        try CatalogService(context: ctx).savePlant(plant, name: "Planta v2", maxCapacity: 10)
        #expect(SyncOutbox.count(in: ctx) == 1)
    }
}
