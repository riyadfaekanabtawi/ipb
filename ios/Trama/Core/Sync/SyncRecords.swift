import CoreData
import Foundation

// Wire format of the platform sync API (platform/src/sync.ts). A change carries one record in
// the backup DTO format (`data`), its `updatedAt` and a `deleted` flag (tombstone).

/// Server entity names, declared in dependency order (parents before children), which is the
/// order pulled upserts are applied in. Deletes run in reverse.
enum SyncEntity: String, CaseIterable, Codable {
    case plants, clients, suppliers, styles, users, contacts, orders, projects, assignments, reports

    /// Core Data entity name.
    var entityName: String {
        switch self {
        case .plants: "Plant"
        case .clients: "Client"
        case .suppliers: "Supplier"
        case .styles: "Style"
        case .users: "AppUser"
        case .contacts: "Contact"
        case .orders: "CutOrder"
        case .projects: "Project"
        case .assignments: "Assignment"
        case .reports: "ProductionReport"
        }
    }

    init?(entityName: String) {
        guard let match = Self.allCases.first(where: { $0.entityName == entityName }) else { return nil }
        self = match
    }

    init?(object: NSManagedObject) {
        guard let name = object.entity.name else { return nil }
        self.init(entityName: name)
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// One record encoded with the backup DTOs.
enum RecordPayload {
    case plant(PlantDTO)
    case client(ClientDTO)
    case supplier(SupplierDTO)
    case contact(ContactDTO)
    case style(StyleDTO)
    case order(CutOrderDTO)
    case assignment(AssignmentDTO)
    case report(ProductionReportDTO)
    case project(ProjectDTO)
    case user(AppUserDTO)

    /// Builds the payload of a live object. Related objects without an id (legacy rows) get one,
    /// so references stay stable once saved.
    init?(_ object: NSManagedObject) {
        let resolve: DTOIDResolver = { related, existing in
            if let existing { return existing }
            let id = UUID()
            related.setValue(id, forKey: "id")
            return id
        }
        switch object {
        case let o as Plant: self = .plant(PlantDTO(o, id: resolve))
        case let o as Client: self = .client(ClientDTO(o, id: resolve))
        case let o as Supplier: self = .supplier(SupplierDTO(o, id: resolve))
        case let o as Contact: self = .contact(ContactDTO(o, id: resolve))
        case let o as Style: self = .style(StyleDTO(o, id: resolve))
        case let o as CutOrder: self = .order(CutOrderDTO(o, id: resolve))
        case let o as Assignment: self = .assignment(AssignmentDTO(o, id: resolve))
        case let o as ProductionReport: self = .report(ProductionReportDTO(o, id: resolve))
        case let o as Project: self = .project(ProjectDTO(o, id: resolve))
        case let o as AppUser: self = .user(AppUserDTO(o, id: resolve))
        default: return nil
        }
    }

    static func decode<K: CodingKey>(
        _ entity: SyncEntity, from container: KeyedDecodingContainer<K>, forKey key: K
    ) throws
        -> RecordPayload?
    {
        guard container.contains(key), try !container.decodeNil(forKey: key) else { return nil }
        switch entity {
        case .plants: return .plant(try container.decode(PlantDTO.self, forKey: key))
        case .clients: return .client(try container.decode(ClientDTO.self, forKey: key))
        case .suppliers: return .supplier(try container.decode(SupplierDTO.self, forKey: key))
        case .contacts: return .contact(try container.decode(ContactDTO.self, forKey: key))
        case .styles: return .style(try container.decode(StyleDTO.self, forKey: key))
        case .orders: return .order(try container.decode(CutOrderDTO.self, forKey: key))
        case .assignments: return .assignment(try container.decode(AssignmentDTO.self, forKey: key))
        case .reports: return .report(try container.decode(ProductionReportDTO.self, forKey: key))
        case .projects: return .project(try container.decode(ProjectDTO.self, forKey: key))
        case .users: return .user(try container.decode(AppUserDTO.self, forKey: key))
        }
    }

    var entity: SyncEntity {
        switch self {
        case .plant: .plants
        case .client: .clients
        case .supplier: .suppliers
        case .contact: .contacts
        case .style: .styles
        case .order: .orders
        case .assignment: .assignments
        case .report: .reports
        case .project: .projects
        case .user: .users
        }
    }

    /// Writes every field into `object` (which must be of the payload's entity).
    func apply(to object: NSManagedObject, lookup: DTORecordLookup) {
        switch self {
        case .plant(let d): (object as? Plant).map { d.apply(to: $0) }
        case .client(let d): (object as? Client).map { d.apply(to: $0) }
        case .supplier(let d): (object as? Supplier).map { d.apply(to: $0) }
        case .contact(let d): (object as? Contact).map { d.apply(to: $0, lookup: lookup) }
        case .style(let d): (object as? Style).map { d.apply(to: $0) }
        case .order(let d): (object as? CutOrder).map { d.apply(to: $0, lookup: lookup) }
        case .assignment(let d): (object as? Assignment).map { d.apply(to: $0, lookup: lookup) }
        case .report(let d): (object as? ProductionReport).map { d.apply(to: $0, lookup: lookup) }
        case .project(let d): (object as? Project).map { d.apply(to: $0, lookup: lookup) }
        case .user(let d): (object as? AppUser).map { d.apply(to: $0, lookup: lookup) }
        }
    }
}

extension RecordPayload: Encodable {
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .plant(let d): try c.encode(d)
        case .client(let d): try c.encode(d)
        case .supplier(let d): try c.encode(d)
        case .contact(let d): try c.encode(d)
        case .style(let d): try c.encode(d)
        case .order(let d): try c.encode(d)
        case .assignment(let d): try c.encode(d)
        case .report(let d): try c.encode(d)
        case .project(let d): try c.encode(d)
        case .user(let d): try c.encode(d)
        }
    }
}

/// A local change sent with `POST /sync/push`.
struct OutgoingChange: Encodable {
    var entity: SyncEntity
    var id: UUID
    var updatedAt: Date
    var deleted: Bool
    var data: RecordPayload?

    /// JSON for the push body: the backup encoding, with every UUID (`id` and `…ID` references)
    /// in canonical lowercase. The server binds each ciphertext to `tenant/entity/id` exactly as
    /// sent while Postgres stores UUIDs lowercase, so an uppercase id would make the record
    /// undecryptable on the next read. Lowercase is also what Android and the web send.
    func wireData() throws -> Data {
        let encoded = try BackupService.encoder.encode(self)
        guard let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return encoded }
        return try JSONSerialization.data(withJSONObject: Self.lowercasingUUIDs(object), options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func lowercasingUUIDs(_ object: [String: Any]) -> [String: Any] {
        var copy = object
        for (key, value) in object {
            if let nested = value as? [String: Any] {
                copy[key] = lowercasingUUIDs(nested)
            } else if let text = value as? String, key == "id" || key.hasSuffix("ID"), UUID(uuidString: text) != nil {
                copy[key] = text.lowercased()
            }
        }
        return copy
    }
}

/// A change received from the server (pull page, or the server copy of a stale push).
struct ServerChange: Decodable {
    /// Nil for an entity this app version doesn't know (ignored).
    var entity: SyncEntity?
    var id: UUID
    var updatedAt: Date
    var deleted: Bool
    var data: RecordPayload?
    var version: Int64

    init(entity: SyncEntity, id: UUID, updatedAt: Date, deleted: Bool, data: RecordPayload?, version: Int64 = 0) {
        self.entity = entity; self.id = id; self.updatedAt = updatedAt; self.deleted = deleted; self.data = data
        self.version = version
    }

    private enum CodingKeys: String, CodingKey { case entity, id, updatedAt, deleted, data, version }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode(String.self, forKey: .entity)
        entity = SyncEntity(rawValue: raw)
        id = try c.decode(UUID.self, forKey: .id)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        version = try c.decodeIfPresent(Int64.self, forKey: .version) ?? 0
        data = try entity.flatMap { try RecordPayload.decode($0, from: c, forKey: .data) }
    }
}

struct LicenceInfo: Codable, Equatable {
    var plan: String
    var status: String
    var expiresAt: Date?
    var writable: Bool

    var planTitle: String {
        switch plan {
        case "web": "Web"
        case "planta": String(localized: "plan.planta", defaultValue: "Planta", comment: "Licence plan name")
        case "multiplanta": String(localized: "plan.multiplanta", defaultValue: "Multiplanta", comment: "Licence plan name")
        case "empresa": String(localized: "plan.empresa", defaultValue: "Empresa", comment: "Licence plan name")
        default: plan.capitalized
        }
    }

    var statusTitle: String {
        switch status {
        case "active": String(localized: "Activa", comment: "Licence status")
        case "expired": String(localized: "Vencida", comment: "Licence status")
        case "suspended": String(localized: "Suspendida", comment: "Licence status")
        default: status
        }
    }
}

struct TenantInfo: Codable, Equatable {
    var id: String
    var name: String
    var plan: String?
}

struct AuthResponse: Decodable {
    var accessToken: String
    var refreshToken: String
    var expiresIn: Int?
    var user: AppUserDTO
    var tenant: TenantInfo
    var licence: LicenceInfo
}

struct PullResponse: Decodable {
    var changes: [ServerChange]
    var cursor: Int64
    var hasMore: Bool
    var licence: LicenceInfo?
}

struct PushResponse: Decodable {
    struct Applied: Decodable {
        var entity: String
        var id: UUID
        var version: Int64
    }

    struct Rejection: Decodable {
        var entity: String
        var id: UUID
        var reason: String
        var message: String
        var server: ServerChange?
    }

    var applied: [Applied]
    var rejected: [Rejection]
    var licence: LicenceInfo?
}
