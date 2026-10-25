import CoreData
import Foundation

// Core Data <-> DTO mapping shared by BackupService (whole-store files) and SyncEngine (one record
// per change). Keeping a single mapping guarantees sync payloads use exactly the backup format.

/// Resolves the UUID written for an object (backups generate one for legacy rows without an id).
typealias DTOIDResolver = (NSManagedObject, UUID?) -> UUID

/// Finds an already-present object by entity name ("Plant", "CutOrder", …) and UUID.
typealias DTORecordLookup = (String, UUID) -> NSManagedObject?

private func ref<T: NSManagedObject>(_ type: T.Type, _ id: UUID?, _ lookup: DTORecordLookup) -> T? {
    guard let id else { return nil }
    return lookup(String(describing: type), id) as? T
}

// MARK: - Object -> DTO

extension PlantDTO {
    init(_ p: Plant, id: DTOIDResolver) {
        self.init(
            id: id(p, p.id), remoteID: p.remoteID, name: p.name, maxCapacity: p.maxCapacity,
            createdAt: p.createdAt, updatedAt: p.updatedAt)
    }

    /// Applies every field; a missing key means "no value" (the payload is the whole record).
    func apply(to p: Plant) {
        p.remoteID = remoteID ?? 0; p.name = name; p.maxCapacity = maxCapacity ?? 0
        p.createdAt = createdAt; p.updatedAt = updatedAt
    }
}

extension ClientDTO {
    init(_ c: Client, id: DTOIDResolver) {
        self.init(
            id: id(c, c.id), remoteID: c.remoteID, name: c.name, address: c.address,
            createdAt: c.createdAt, updatedAt: c.updatedAt)
    }

    func apply(to c: Client) {
        c.remoteID = remoteID ?? 0; c.name = name; c.address = address
        c.createdAt = createdAt; c.updatedAt = updatedAt
    }
}

extension SupplierDTO {
    init(_ s: Supplier, id: DTOIDResolver) {
        self.init(
            id: id(s, s.id), remoteID: s.remoteID, name: s.name, address: s.address,
            createdAt: s.createdAt, updatedAt: s.updatedAt)
    }

    func apply(to s: Supplier) {
        s.remoteID = remoteID ?? 0; s.name = name; s.address = address
        s.createdAt = createdAt; s.updatedAt = updatedAt
    }
}

extension ContactDTO {
    init(_ c: Contact, id: DTOIDResolver) {
        self.init(
            id: id(c, c.id), name: c.name, email: c.email, phone: c.phone, role: c.role, sortIndex: c.sortIndex,
            clientID: c.client.map { id($0, $0.id) }, supplierID: c.supplier.map { id($0, $0.id) })
    }

    func apply(to c: Contact, lookup: DTORecordLookup) {
        c.name = name; c.email = email; c.phone = phone; c.role = role
        c.sortIndex = sortIndex ?? 0
        c.client = ref(Client.self, clientID, lookup)
        c.supplier = ref(Supplier.self, supplierID, lookup)
    }
}

extension StyleDTO {
    init(_ s: Style, id: DTOIDResolver) {
        self.init(
            id: id(s, s.id), remoteID: s.remoteID, name: s.name, imageData: s.imageData,
            createdAt: s.createdAt, updatedAt: s.updatedAt)
    }

    func apply(to s: Style) {
        s.remoteID = remoteID ?? 0; s.name = name; s.imageData = imageData
        s.createdAt = createdAt; s.updatedAt = updatedAt
    }
}

extension CutOrderDTO {
    init(_ o: CutOrder, id: DTOIDResolver) {
        self.init(
            id: id(o, o.id), remoteID: o.remoteID, code: o.code, list: o.list, garment: o.garment,
            quantity: o.quantity, unitPrice: o.unitPrice, internalDate: o.internalDate, clientDate: o.clientDate,
            editedBy: o.editedBy, notes: o.notes, createdAt: o.createdAt, updatedAt: o.updatedAt,
            clientID: o.client.map { id($0, $0.id) }, styleID: o.style.map { id($0, $0.id) })
    }

    func apply(to o: CutOrder, lookup: DTORecordLookup) {
        o.remoteID = remoteID ?? 0; o.code = code; o.list = list; o.garment = garment
        o.quantity = quantity ?? 0; o.unitPrice = unitPrice ?? 0; o.internalDate = internalDate; o.clientDate = clientDate
        o.editedBy = editedBy; o.notes = notes; o.createdAt = createdAt; o.updatedAt = updatedAt
        o.client = ref(Client.self, clientID, lookup)
        o.style = ref(Style.self, styleID, lookup)
    }
}

extension AssignmentDTO {
    init(_ a: Assignment, id: DTOIDResolver) {
        self.init(
            id: id(a, a.id), remoteID: a.remoteID, quantity: a.quantity, unitPrice: a.unitPrice,
            scheduledDate: a.scheduledDate, cuttingStatusRaw: a.cuttingStatusRaw,
            createdAt: a.createdAt, updatedAt: a.updatedAt,
            orderID: a.order.map { id($0, $0.id) }, plantID: a.plant.map { id($0, $0.id) })
    }

    func apply(to a: Assignment, lookup: DTORecordLookup) {
        a.remoteID = remoteID ?? 0; a.quantity = quantity ?? 0; a.unitPrice = unitPrice ?? 0
        a.scheduledDate = scheduledDate; a.cuttingStatusRaw = cuttingStatusRaw ?? CutStatus.waiting.rawValue
        a.createdAt = createdAt; a.updatedAt = updatedAt
        a.order = ref(CutOrder.self, orderID, lookup)
        a.plant = ref(Plant.self, plantID, lookup)
    }
}

extension ProductionReportDTO {
    init(_ r: ProductionReport, id: DTOIDResolver) {
        self.init(
            id: id(r, r.id), remoteID: r.remoteID, kindRaw: r.kindRaw, cutStatusRaw: r.cutStatusRaw,
            authorName: r.authorName, operators: r.operators, absences: r.absences, produced: r.produced,
            ironing: r.ironing, packing: r.packing, warehouse: r.warehouse, realQuantity: r.realQuantity,
            shipmentNumber: r.shipmentNumber, shippedQuantity: r.shippedQuantity,
            createdAt: r.createdAt, updatedAt: r.updatedAt, assignmentID: r.assignment.map { id($0, $0.id) })
    }

    func apply(to r: ProductionReport, lookup: DTORecordLookup) {
        r.remoteID = remoteID ?? 0; r.kindRaw = kindRaw; r.cutStatusRaw = cutStatusRaw
        r.authorName = authorName; r.operators = operators ?? 0; r.absences = absences ?? 0
        r.produced = produced ?? 0; r.ironing = ironing ?? 0; r.packing = packing ?? 0
        r.warehouse = warehouse ?? 0; r.realQuantity = realQuantity ?? 0; r.shipmentNumber = shipmentNumber
        r.shippedQuantity = shippedQuantity ?? 0; r.createdAt = createdAt; r.updatedAt = updatedAt
        r.assignment = ref(Assignment.self, assignmentID, lookup)
    }
}

extension ProjectDTO {
    init(_ p: Project, id: DTOIDResolver) {
        self.init(
            id: id(p, p.id), remoteID: p.remoteID, clientName: p.clientName, quantity: p.quantity, price: p.price,
            minutes: p.minutes, fabric: p.fabric, deliveryDate: p.deliveryDate, notes: p.notes, photoData: p.photoData,
            statusRaw: p.statusRaw, createdAt: p.createdAt, updatedAt: p.updatedAt, clientID: p.client.map { id($0, $0.id) })
    }

    func apply(to p: Project, lookup: DTORecordLookup) {
        p.remoteID = remoteID ?? 0; p.clientName = clientName; p.quantity = quantity ?? 0
        p.price = price ?? 0; p.minutes = minutes ?? 0; p.fabric = fabric; p.deliveryDate = deliveryDate
        p.notes = notes; p.photoData = photoData; p.statusRaw = statusRaw ?? ProjectStatus.pending.rawValue
        p.createdAt = createdAt; p.updatedAt = updatedAt
        p.client = ref(Client.self, clientID, lookup)
    }
}

extension AppUserDTO {
    init(_ u: AppUser, id: DTOIDResolver) {
        self.init(
            id: id(u, u.id), remoteID: u.remoteID, email: u.email, firstName: u.firstName, lastName: u.lastName,
            phone: u.phone, roleRaw: u.roleRaw, isActive: u.isActive, passwordHash: u.passwordHash,
            passwordSalt: u.passwordSalt, avatarData: u.avatarData, createdAt: u.createdAt, updatedAt: u.updatedAt,
            plantID: u.plant.map { id($0, $0.id) })
    }

    func apply(to u: AppUser, lookup: DTORecordLookup) {
        u.remoteID = remoteID ?? 0; u.email = email; u.firstName = firstName
        u.lastName = lastName; u.phone = phone; u.roleRaw = roleRaw; u.isActive = isActive ?? true
        u.passwordHash = passwordHash; u.passwordSalt = passwordSalt; u.avatarData = avatarData
        u.createdAt = createdAt; u.updatedAt = updatedAt
        u.plant = ref(Plant.self, plantID, lookup)
    }
}
