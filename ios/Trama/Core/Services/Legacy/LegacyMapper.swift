import Foundation

// Pure legacy JSON → value mappings (no Core Data), so every field rule is unit-testable.
// Key names come from the legacy Objective-C models in the legacy IPB app (IPB/Common/*.m, see git history).

struct LegacyPlant: Equatable {
    var remoteID: Int64
    var name: String?
    var maxCapacity: Double
}

struct LegacyContact: Equatable {
    var name: String?
    var email: String?
    var phone: String?
    var role: String?
}

/// Clients and suppliers share the same shape (`Cliente.m` / `Proveedores.m`).
struct LegacyCompany: Equatable {
    var remoteID: Int64
    var name: String?
    var address: String?
    var contacts: [LegacyContact]
}

struct LegacyStyle: Equatable {
    var remoteID: Int64
    var name: String?
    var photoPath: String?
}

struct LegacyUser: Equatable {
    var remoteID: Int64
    var firstName: String?
    var lastName: String?
    var email: String?
    var role: Role
    var phone: String?
    var plantName: String?
}

struct LegacyProject: Equatable {
    var remoteID: Int64
    var quantity: Int64
    var price: Double
    var minutes: Double
    var status: ProjectStatus
    var clientName: String?
    var fabric: String?
    var deliveryDate: Date?
    var notes: String?
    var photoPath: String?
}

/// A cut order (`PendingCut.m`).
struct LegacyPendingCut: Equatable {
    var remoteID: Int64
    var clientName: String?
    var styleName: String?
    var quantity: Int64
    var unitPrice: Double
    var code: String?
    var list: String?
    var garment: String?
    var internalDate: Date?
    var clientDate: Date?
    var editedBy: String?
}

/// A cut assigned to a plant (`Corte.m`).
struct LegacyCut: Equatable {
    var remoteID: Int64
    var plantRemoteID: Int64?
    var quantity: Int64
    var unitPrice: Double
    var scheduledDate: Date?
    var status: CutStatus
    var code: String?
    var list: String?
    var clientName: String?
    var styleName: String?
    var garment: String?
    var clientDate: Date?
}

struct LegacyReport: Equatable {
    var remoteID: Int64
    var kind: ReportKind
    var cutRemoteID: Int64?
    var createdAt: Date?
    var operators: Int64 = 0
    var absences: Int64 = 0
    var produced: Int64 = 0
    var ironing: Int64 = 0
    var packing: Int64 = 0
    var warehouse: Int64 = 0
    var cutStatus: CutStatus?
    var realQuantity: Int64 = 0
    var shipmentNumber: String?
    var shippedQuantity: Int64 = 0
}

enum LegacyMapper {
    /// Rows without a usable id cannot be upserted and are skipped.
    private static func remoteID(_ row: LegacyRow) -> Int64? {
        guard let id = row.int("id"), id > 0 else { return nil }
        return Int64(id)
    }

    private static func i64(_ row: LegacyRow, _ key: String) -> Int64 { Int64(max(0, row.int(key) ?? 0)) }

    static func plant(_ row: LegacyRow) -> LegacyPlant? {
        guard let id = remoteID(row) else { return nil }
        return LegacyPlant(remoteID: id, name: row.text("name"), maxCapacity: max(0, row.double("max_capacity") ?? 0))
    }

    static func company(_ row: LegacyRow) -> LegacyCompany? {
        guard let id = remoteID(row) else { return nil }
        let contacts = (1...3).compactMap { n -> LegacyContact? in
            let c = LegacyContact(
                name: row.text("nombre_contacto\(n)"), email: row.text("email_contacto\(n)"),
                phone: row.text("telefono_contacto\(n)"), role: row.text("puesto_contacto\(n)"))
            return [c.name, c.email, c.phone, c.role].allSatisfy({ $0 == nil }) ? nil : c
        }
        return LegacyCompany(remoteID: id, name: row.text("nombre"), address: row.text("direccion"), contacts: contacts)
    }

    static func style(_ row: LegacyRow) -> LegacyStyle? {
        guard let id = remoteID(row) else { return nil }
        return LegacyStyle(remoteID: id, name: row.text("name"), photoPath: row.text("photo"))
    }

    /// Login responses nested the user under "user"; list responses did not.
    static func user(_ row: LegacyRow) -> LegacyUser? {
        var row = row
        if case .object(let nested)? = row["user"] { row = nested }
        guard let id = remoteID(row) else { return nil }
        return LegacyUser(
            remoteID: id, firstName: row.text("nombre"), lastName: row.text("apellido"),
            email: row.text("email")?.lowercased(), role: role(row.text("puesto")), phone: row.text("telefono"),
            plantName: row.text("plant_name"))
    }

    static func project(_ row: LegacyRow) -> LegacyProject? {
        guard let id = remoteID(row) else { return nil }
        return LegacyProject(
            remoteID: id, quantity: i64(row, "cantidad"), price: max(0, row.double("precio") ?? 0),
            minutes: max(0, row.double("minutaje") ?? 0), status: projectStatus(row.text("status")),
            clientName: row.text("cliente"), fabric: row.text("tela"), deliveryDate: row.date("fecha_entrega"),
            notes: row.text("notes"), photoPath: row.text("photo"))
    }

    static func pendingCut(_ row: LegacyRow) -> LegacyPendingCut? {
        guard let id = remoteID(row) else { return nil }
        return LegacyPendingCut(
            remoteID: id, clientName: row.text("cliente"), styleName: row.text("estilo"), quantity: i64(row, "cantidad"),
            unitPrice: max(0, row.double("precio_unitario") ?? 0), code: row.text("corte"), list: row.text("lista"),
            garment: row.text("prenda"), internalDate: row.date("fecha_ipb"), clientDate: row.date("fecha_cliente"),
            editedBy: row.text("editado_por"))
    }

    static func cut(_ row: LegacyRow) -> LegacyCut? {
        guard let id = remoteID(row) else { return nil }
        var plantID = row.int("plant_id").map(Int64.init)
        if plantID == nil, case .object(let plant)? = row["plant"], let nested = plant.int("id") { plantID = Int64(nested) }
        return LegacyCut(
            remoteID: id, plantRemoteID: plantID, quantity: i64(row, "cantidad"),
            unitPrice: max(0, row.double("precio_unitario") ?? 0), scheduledDate: row.date("fecha_ipb"),
            status: CutStatus(legacy: row.text("status")), code: row.text("corte"), list: row.text("lista"),
            clientName: row.text("cliente"), styleName: row.text("estilo_cliente") ?? row.text("estilo"),
            garment: row.text("prenda"), clientDate: row.date("fecha_cliente"))
    }

    static func report(_ row: LegacyRow) -> LegacyReport? {
        guard let id = remoteID(row) else { return nil }
        let kind = ReportKind(rawValue: normalized(row.text("tipo"))) ?? .plant
        var r = LegacyReport(remoteID: id, kind: kind, cutRemoteID: row.int("cut_id").map(Int64.init), createdAt: row.date("created_at"))
        switch kind {
        case .plant:
            r.operators = i64(row, "operarios")
            r.absences = i64(row, "faltas")
            r.produced = i64(row, "produciad")  // sic: legacy column name
            r.ironing = i64(row, "en_plancha")
            r.packing = i64(row, "en_empaque")
            r.warehouse = i64(row, "bodega")
        case .cut:
            r.cutStatus = CutStatus(legacy: row.text("status"))
            r.realQuantity = i64(row, "cantidad_real_envio")
        case .shipment:
            r.shipmentNumber = row.text("numero_de_envio")
            r.shippedQuantity = i64(row, "cantidad_de_envio")
        }
        return r
    }

    // MARK: Enum mapping

    static func role(_ puesto: String?) -> Role {
        let p = normalized(puesto)
        if p.contains("admin") { return .admin }
        if p.contains("corte") { return .cutManager }
        if p.contains("envio") { return .shippingManager }
        return .plantManager
    }

    static func projectStatus(_ raw: String?) -> ProjectStatus {
        let s = normalized(raw)
        if s.hasPrefix("acept") { return .accepted }
        if s.hasPrefix("declin") || s.hasPrefix("rechaz") { return .declined }
        return .pending
    }

    /// Lowercased, accent-free, trimmed ("Envío" → "envio").
    static func normalized(_ raw: String?) -> String {
        (raw ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "es_MX")).lowercased()
            .trimmingCharacters(in: .whitespaces)
    }
}
