import CoreData
import Foundation

/// Versioned JSON backup of the whole store. Relationships are encoded by entity UUID and
/// binary images as base64. Every DTO field is optional so newer/older files decode
/// (missing keys simply keep the model defaults).
enum BackupService {
    static let formatVersion = 1

    enum BackupError: LocalizedError, Equatable {
        case invalidFile
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .invalidFile: "El archivo no es un respaldo válido de Trama."
            case .unsupportedVersion(let v):
                "Este respaldo es de una versión más nueva de Trama (formato \(v)). Actualiza la app para restaurarlo."
            }
        }
    }

    /// Lightweight description shown before a destructive restore.
    struct Summary: Equatable {
        var exportedAt: Date?
        var appVersion: String?
        var counts: [(String, Int)]

        var total: Int { counts.reduce(0) { $0 + $1.1 } }

        static func == (l: Summary, r: Summary) -> Bool {
            l.exportedAt == r.exportedAt && l.appVersion == r.appVersion && l.counts.map(\.0) == r.counts.map(\.0)
                && l.counts.map(\.1) == r.counts.map(\.1)
        }
    }

    // MARK: Export

    static func export(context: NSManagedObjectContext, now: Date = .now) throws -> Data {
        var ids = IDMap()
        let plants = context.fetchAll(Plant.self)
        let clients = context.fetchAll(Client.self)
        let suppliers = context.fetchAll(Supplier.self)
        let contacts = context.fetchAll(Contact.self)
        let styles = context.fetchAll(Style.self)
        let orders = context.fetchAll(CutOrder.self)
        let assignments = context.fetchAll(Assignment.self)
        let reports = context.fetchAll(ProductionReport.self)
        let projects = context.fetchAll(Project.self)
        let users = context.fetchAll(AppUser.self)

        let file = BackupFile(
            formatVersion: formatVersion,
            exportedAt: now,
            appVersion: appVersion,
            plants: plants.map { p in
                PlantDTO(
                    id: ids[p, p.id], remoteID: p.remoteID, name: p.name, maxCapacity: p.maxCapacity,
                    createdAt: p.createdAt, updatedAt: p.updatedAt)
            },
            clients: clients.map { c in
                ClientDTO(
                    id: ids[c, c.id], remoteID: c.remoteID, name: c.name, address: c.address,
                    createdAt: c.createdAt, updatedAt: c.updatedAt)
            },
            suppliers: suppliers.map { s in
                SupplierDTO(
                    id: ids[s, s.id], remoteID: s.remoteID, name: s.name, address: s.address,
                    createdAt: s.createdAt, updatedAt: s.updatedAt)
            },
            contacts: contacts.map { c in
                ContactDTO(
                    id: ids[c, c.id], name: c.name, email: c.email, phone: c.phone, role: c.role, sortIndex: c.sortIndex,
                    clientID: c.client.map { ids[$0, $0.id] }, supplierID: c.supplier.map { ids[$0, $0.id] })
            },
            styles: styles.map { s in
                StyleDTO(
                    id: ids[s, s.id], remoteID: s.remoteID, name: s.name, imageData: s.imageData,
                    createdAt: s.createdAt, updatedAt: s.updatedAt)
            },
            orders: orders.map { o in
                CutOrderDTO(
                    id: ids[o, o.id], remoteID: o.remoteID, code: o.code, list: o.list, garment: o.garment,
                    quantity: o.quantity, unitPrice: o.unitPrice, internalDate: o.internalDate, clientDate: o.clientDate,
                    editedBy: o.editedBy, notes: o.notes, createdAt: o.createdAt, updatedAt: o.updatedAt,
                    clientID: o.client.map { ids[$0, $0.id] }, styleID: o.style.map { ids[$0, $0.id] })
            },
            assignments: assignments.map { a in
                AssignmentDTO(
                    id: ids[a, a.id], remoteID: a.remoteID, quantity: a.quantity, unitPrice: a.unitPrice,
                    scheduledDate: a.scheduledDate, cuttingStatusRaw: a.cuttingStatusRaw,
                    createdAt: a.createdAt, updatedAt: a.updatedAt,
                    orderID: a.order.map { ids[$0, $0.id] }, plantID: a.plant.map { ids[$0, $0.id] })
            },
            reports: reports.map { r in
                ProductionReportDTO(
                    id: ids[r, r.id], remoteID: r.remoteID, kindRaw: r.kindRaw, cutStatusRaw: r.cutStatusRaw,
                    authorName: r.authorName, operators: r.operators, absences: r.absences, produced: r.produced,
                    ironing: r.ironing, packing: r.packing, warehouse: r.warehouse, realQuantity: r.realQuantity,
                    shipmentNumber: r.shipmentNumber, shippedQuantity: r.shippedQuantity,
                    createdAt: r.createdAt, updatedAt: r.updatedAt, assignmentID: r.assignment.map { ids[$0, $0.id] })
            },
            projects: projects.map { p in
                ProjectDTO(
                    id: ids[p, p.id], remoteID: p.remoteID, clientName: p.clientName, quantity: p.quantity, price: p.price,
                    minutes: p.minutes, fabric: p.fabric, deliveryDate: p.deliveryDate, notes: p.notes, photoData: p.photoData,
                    statusRaw: p.statusRaw, createdAt: p.createdAt, updatedAt: p.updatedAt, clientID: p.client.map { ids[$0, $0.id] })
            },
            users: users.map { u in
                AppUserDTO(
                    id: ids[u, u.id], remoteID: u.remoteID, email: u.email, firstName: u.firstName, lastName: u.lastName,
                    phone: u.phone, roleRaw: u.roleRaw, isActive: u.isActive, passwordHash: u.passwordHash,
                    passwordSalt: u.passwordSalt, avatarData: u.avatarData, createdAt: u.createdAt, updatedAt: u.updatedAt,
                    plantID: u.plant.map { ids[$0, $0.id] })
            }
        )
        return try encoder.encode(file)
    }

    // MARK: Inspect / restore

    /// Decodes and validates a backup without touching the store.
    static func inspect(_ data: Data) throws -> Summary {
        let file = try decode(data)
        return Summary(
            exportedAt: file.exportedAt, appVersion: file.appVersion,
            counts: [
                ("Plantas", file.plants?.count ?? 0), ("Clientes", file.clients?.count ?? 0),
                ("Proveedores", file.suppliers?.count ?? 0), ("Estilos", file.styles?.count ?? 0),
                ("Cortes", file.orders?.count ?? 0), ("Asignaciones", file.assignments?.count ?? 0),
                ("Reportes", file.reports?.count ?? 0), ("Proyectos", file.projects?.count ?? 0),
                ("Usuarios", file.users?.count ?? 0),
            ])
    }

    /// Replaces the whole store with the backup. The file is fully decoded and validated
    /// before anything is erased, so a bad file never destroys local data.
    static func restore(_ data: Data, into persistence: PersistenceController) throws {
        let file = try decode(data)
        try persistence.eraseAll()
        let context = persistence.viewContext

        func uuid(_ value: UUID?) -> UUID { value ?? UUID() }

        var plants: [UUID: Plant] = [:]
        for d in file.plants ?? [] {
            let p = Plant(context: context)
            p.id = uuid(d.id); p.remoteID = d.remoteID ?? 0; p.name = d.name; p.maxCapacity = d.maxCapacity ?? 0
            p.createdAt = d.createdAt; p.updatedAt = d.updatedAt
            plants[p.id!] = p
        }
        var clients: [UUID: Client] = [:]
        for d in file.clients ?? [] {
            let c = Client(context: context)
            c.id = uuid(d.id); c.remoteID = d.remoteID ?? 0; c.name = d.name; c.address = d.address
            c.createdAt = d.createdAt; c.updatedAt = d.updatedAt
            clients[c.id!] = c
        }
        var suppliers: [UUID: Supplier] = [:]
        for d in file.suppliers ?? [] {
            let s = Supplier(context: context)
            s.id = uuid(d.id); s.remoteID = d.remoteID ?? 0; s.name = d.name; s.address = d.address
            s.createdAt = d.createdAt; s.updatedAt = d.updatedAt
            suppliers[s.id!] = s
        }
        for d in file.contacts ?? [] {
            let c = Contact(context: context)
            c.id = uuid(d.id); c.name = d.name; c.email = d.email; c.phone = d.phone; c.role = d.role
            c.sortIndex = d.sortIndex ?? 0
            c.client = d.clientID.flatMap { clients[$0] }
            c.supplier = d.supplierID.flatMap { suppliers[$0] }
        }
        var styles: [UUID: Style] = [:]
        for d in file.styles ?? [] {
            let s = Style(context: context)
            s.id = uuid(d.id); s.remoteID = d.remoteID ?? 0; s.name = d.name; s.imageData = d.imageData
            s.createdAt = d.createdAt; s.updatedAt = d.updatedAt
            styles[s.id!] = s
        }
        var orders: [UUID: CutOrder] = [:]
        for d in file.orders ?? [] {
            let o = CutOrder(context: context)
            o.id = uuid(d.id); o.remoteID = d.remoteID ?? 0; o.code = d.code; o.list = d.list; o.garment = d.garment
            o.quantity = d.quantity ?? 0; o.unitPrice = d.unitPrice ?? 0; o.internalDate = d.internalDate; o.clientDate = d.clientDate
            o.editedBy = d.editedBy; o.notes = d.notes; o.createdAt = d.createdAt; o.updatedAt = d.updatedAt
            o.client = d.clientID.flatMap { clients[$0] }
            o.style = d.styleID.flatMap { styles[$0] }
            orders[o.id!] = o
        }
        var assignments: [UUID: Assignment] = [:]
        for d in file.assignments ?? [] {
            let a = Assignment(context: context)
            a.id = uuid(d.id); a.remoteID = d.remoteID ?? 0; a.quantity = d.quantity ?? 0; a.unitPrice = d.unitPrice ?? 0
            a.scheduledDate = d.scheduledDate; a.cuttingStatusRaw = d.cuttingStatusRaw ?? CutStatus.waiting.rawValue
            a.createdAt = d.createdAt; a.updatedAt = d.updatedAt
            a.order = d.orderID.flatMap { orders[$0] }
            a.plant = d.plantID.flatMap { plants[$0] }
            assignments[a.id!] = a
        }
        for d in file.reports ?? [] {
            let r = ProductionReport(context: context)
            r.id = uuid(d.id); r.remoteID = d.remoteID ?? 0; r.kindRaw = d.kindRaw; r.cutStatusRaw = d.cutStatusRaw
            r.authorName = d.authorName; r.operators = d.operators ?? 0; r.absences = d.absences ?? 0
            r.produced = d.produced ?? 0; r.ironing = d.ironing ?? 0; r.packing = d.packing ?? 0
            r.warehouse = d.warehouse ?? 0; r.realQuantity = d.realQuantity ?? 0; r.shipmentNumber = d.shipmentNumber
            r.shippedQuantity = d.shippedQuantity ?? 0; r.createdAt = d.createdAt; r.updatedAt = d.updatedAt
            r.assignment = d.assignmentID.flatMap { assignments[$0] }
        }
        for d in file.projects ?? [] {
            let p = Project(context: context)
            p.id = uuid(d.id); p.remoteID = d.remoteID ?? 0; p.clientName = d.clientName; p.quantity = d.quantity ?? 0
            p.price = d.price ?? 0; p.minutes = d.minutes ?? 0; p.fabric = d.fabric; p.deliveryDate = d.deliveryDate
            p.notes = d.notes; p.photoData = d.photoData; p.statusRaw = d.statusRaw ?? ProjectStatus.pending.rawValue
            p.createdAt = d.createdAt; p.updatedAt = d.updatedAt
            p.client = d.clientID.flatMap { clients[$0] }
        }
        for d in file.users ?? [] {
            let u = AppUser(context: context)
            u.id = uuid(d.id); u.remoteID = d.remoteID ?? 0; u.email = d.email; u.firstName = d.firstName
            u.lastName = d.lastName; u.phone = d.phone; u.roleRaw = d.roleRaw; u.isActive = d.isActive ?? true
            u.passwordHash = d.passwordHash; u.passwordSalt = d.passwordSalt; u.avatarData = d.avatarData
            u.createdAt = d.createdAt; u.updatedAt = d.updatedAt
            u.plant = d.plantID.flatMap { plants[$0] }
        }
        try context.saveIfNeeded()
    }

    /// "Trama-respaldo-2026-10-24.json"
    static func filename(for date: Date = .now) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "Trama-respaldo-\(f.string(from: date)).json"
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    // MARK: Coding

    private static func decode(_ data: Data) throws -> BackupFile {
        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }
        guard let version = file.formatVersion, version >= 1 else { throw BackupError.invalidFile }
        guard version <= formatVersion else { throw BackupError.unsupportedVersion(version) }
        return file
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        e.dataEncodingStrategy = .base64
        // Fractional seconds matter: "latest report wins" ordering relies on createdAt.
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try c.encode(f.string(from: date))
        }
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dataDecodingStrategy = .base64
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let raw = try c.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Fecha inválida: \(raw)")
        }
        return d
    }()

    /// Stable UUID per object, generating one for legacy rows that never got an id.
    private struct IDMap {
        private var generated: [NSManagedObjectID: UUID] = [:]
        subscript(object: NSManagedObject, existing: UUID?) -> UUID {
            mutating get {
                if let existing { return existing }
                if let id = generated[object.objectID] { return id }
                let id = UUID()
                generated[object.objectID] = id
                return id
            }
        }
    }
}

// MARK: - DTOs

/// Top-level file. Arrays are optional so a file missing an entity still restores.
struct BackupFile: Codable {
    var formatVersion: Int?
    var exportedAt: Date?
    var appVersion: String?
    var plants: [PlantDTO]?
    var clients: [ClientDTO]?
    var suppliers: [SupplierDTO]?
    var contacts: [ContactDTO]?
    var styles: [StyleDTO]?
    var orders: [CutOrderDTO]?
    var assignments: [AssignmentDTO]?
    var reports: [ProductionReportDTO]?
    var projects: [ProjectDTO]?
    var users: [AppUserDTO]?
}

struct PlantDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var name: String? = nil
    var maxCapacity: Double? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
}

struct ClientDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var name: String? = nil
    var address: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
}

struct SupplierDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var name: String? = nil
    var address: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
}

struct ContactDTO: Codable {
    var id: UUID? = nil
    var name: String? = nil
    var email: String? = nil
    var phone: String? = nil
    var role: String? = nil
    var sortIndex: Int16? = nil
    var clientID: UUID? = nil
    var supplierID: UUID? = nil
}

struct StyleDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var name: String? = nil
    var imageData: Data? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
}

struct CutOrderDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var code: String? = nil
    var list: String? = nil
    var garment: String? = nil
    var quantity: Int64? = nil
    var unitPrice: Double? = nil
    var internalDate: Date? = nil
    var clientDate: Date? = nil
    var editedBy: String? = nil
    var notes: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var clientID: UUID? = nil
    var styleID: UUID? = nil
}

struct AssignmentDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var quantity: Int64? = nil
    var unitPrice: Double? = nil
    var scheduledDate: Date? = nil
    var cuttingStatusRaw: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var orderID: UUID? = nil
    var plantID: UUID? = nil
}

struct ProductionReportDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var kindRaw: String? = nil
    var cutStatusRaw: String? = nil
    var authorName: String? = nil
    var operators: Int64? = nil
    var absences: Int64? = nil
    var produced: Int64? = nil
    var ironing: Int64? = nil
    var packing: Int64? = nil
    var warehouse: Int64? = nil
    var realQuantity: Int64? = nil
    var shipmentNumber: String? = nil
    var shippedQuantity: Int64? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var assignmentID: UUID? = nil
}

struct ProjectDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var clientName: String? = nil
    var quantity: Int64? = nil
    var price: Double? = nil
    var minutes: Double? = nil
    var fabric: String? = nil
    var deliveryDate: Date? = nil
    var notes: String? = nil
    var photoData: Data? = nil
    var statusRaw: String? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var clientID: UUID? = nil
}

struct AppUserDTO: Codable {
    var id: UUID? = nil
    var remoteID: Int64? = nil
    var email: String? = nil
    var firstName: String? = nil
    var lastName: String? = nil
    var phone: String? = nil
    var roleRaw: String? = nil
    var isActive: Bool? = nil
    var passwordHash: String? = nil
    var passwordSalt: String? = nil
    var avatarData: Data? = nil
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var plantID: UUID? = nil
}
