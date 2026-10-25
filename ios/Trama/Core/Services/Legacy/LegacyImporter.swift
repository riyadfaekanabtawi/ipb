import CoreData
import Foundation

/// Per-resource outcome of an import run.
struct LegacyImportSummary: Equatable {
    struct Count: Equatable {
        var created = 0
        var updated = 0
        var skipped = 0
        var total: Int { created + updated }
    }

    var counts: [LegacyResource: Count] = [:]
    var imagesDownloaded = 0

    subscript(resource: LegacyResource) -> Count {
        get { counts[resource] ?? Count() }
        set { counts[resource] = newValue }
    }

    var totalCreated: Int { counts.values.reduce(0) { $0 + $1.created } }
    var totalUpdated: Int { counts.values.reduce(0) { $0 + $1.updated } }
}

/// Imports the legacy Rails data into Core Data, upserting every entity by `remoteID` so
/// running it again updates instead of duplicating. Local-only objects (remoteID 0) are never touched.
///
/// Imported users get a random password and `isActive = false`: the old server's passwords
/// cannot be migrated, so an administrator must set a password and activate each user.
@MainActor
final class LegacyImporter {
    let context: NSManagedObjectContext
    private(set) var summary = LegacyImportSummary()

    // Caches keyed by remoteID, filled from the store up front so lookups are O(1).
    private var plants: [Int64: Plant] = [:]
    private var clients: [Int64: Client] = [:]
    private var suppliers: [Int64: Supplier] = [:]
    private var styles: [Int64: Style] = [:]
    private var users: [Int64: AppUser] = [:]
    private var projects: [Int64: Project] = [:]
    private var orders: [Int64: CutOrder] = [:]
    private var assignments: [Int64: Assignment] = [:]
    private var reports: [Int64: ProductionReport] = [:]

    private var cachesLoaded = false

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Runs the full import. `progress` reports (finished steps, total steps, current resource).
    func run(
        from source: LegacySource, downloadImages: Bool = true,
        progress: (Int, Int, LegacyResource) -> Void = { _, _, _ in }
    ) async throws -> LegacyImportSummary {
        summary = LegacyImportSummary()
        loadCaches()
        let resources = LegacyResource.allCases
        var pendingImages: [(NSManagedObject, String)] = []
        for (index, resource) in resources.enumerated() {
            progress(index, resources.count, resource)
            let rows = try await source.rows(for: resource)
            pendingImages += apply(resource, rows: rows)
            try context.saveIfNeeded()
        }
        progress(resources.count, resources.count, .reports)

        if downloadImages {
            // Best effort: a missing photo never fails the import.
            for (object, path) in pendingImages {
                guard let data = try? await source.asset(at: path), let compressed = ImageCompressor.compress(data) else { continue }
                if let style = object as? Style { style.imageData = compressed }
                if let project = object as? Project { project.photoData = compressed }
                summary.imagesDownloaded += 1
            }
            try context.saveIfNeeded()
        }
        return summary
    }

    /// Applies one endpoint's rows. Returns objects whose photo still needs downloading.
    @discardableResult
    func apply(_ resource: LegacyResource, rows: [LegacyRow]) -> [(NSManagedObject, String)] {
        if !cachesLoaded { loadCaches() }
        var images: [(NSManagedObject, String)] = []
        for row in rows {
            switch resource {
            case .plants: importPlant(row)
            case .clients: importCompany(row, supplier: false)
            case .suppliers: importCompany(row, supplier: true)
            case .styles: if let pair = importStyle(row) { images.append(pair) }
            case .users: importUser(row)
            case .projects: if let pair = importProject(row) { images.append(pair) }
            case .pendingCuts: importPendingCut(row)
            case .cuts: importCut(row)
            case .reports: importReport(row)
            }
        }
        if resource == .reports { syncCuttingStatus() }
        return images
    }

    // MARK: Entities

    private func importPlant(_ row: LegacyRow) {
        guard let dto = LegacyMapper.plant(row) else { return skip(.plants) }
        let (plant, created) = upsert(Plant.self, dto.remoteID, cache: &plants, resource: .plants)
        plant.name = dto.name ?? plant.name ?? "Planta \(dto.remoteID)"
        plant.maxCapacity = dto.maxCapacity
        finish(plant, created)
    }

    private func importCompany(_ row: LegacyRow, supplier: Bool) {
        let resource: LegacyResource = supplier ? .suppliers : .clients
        guard let dto = LegacyMapper.company(row) else { return skip(resource) }
        let owner: NSManagedObject & Timestamped
        let created: Bool
        if supplier {
            let pair = upsert(Supplier.self, dto.remoteID, cache: &suppliers, resource: resource)
            pair.0.name = dto.name ?? pair.0.name
            pair.0.address = dto.address
            owner = pair.0
            created = pair.1
        } else {
            let pair = upsert(Client.self, dto.remoteID, cache: &clients, resource: resource)
            pair.0.name = dto.name ?? pair.0.name
            pair.0.address = dto.address
            owner = pair.0
            created = pair.1
        }
        // Contacts are replaced wholesale: the legacy model only had three fixed slots.
        let existing = (owner.value(forKey: "contacts") as? Set<Contact>) ?? []
        existing.forEach(context.delete)
        for (index, c) in dto.contacts.enumerated() {
            let contact = Contact(context: context)
            contact.id = UUID()
            contact.name = c.name; contact.email = c.email; contact.phone = c.phone; contact.role = c.role
            contact.sortIndex = Int16(index)
            if let client = owner as? Client { contact.client = client }
            if let supplier = owner as? Supplier { contact.supplier = supplier }
        }
        finish(owner, created)
    }

    private func importStyle(_ row: LegacyRow) -> (NSManagedObject, String)? {
        guard let dto = LegacyMapper.style(row) else { skip(.styles); return nil }
        let (style, created) = upsert(Style.self, dto.remoteID, cache: &styles, resource: .styles)
        style.name = dto.name ?? style.name
        finish(style, created)
        guard style.imageData == nil, let path = dto.photoPath else { return nil }
        return (style, path)
    }

    private func importUser(_ row: LegacyRow) {
        guard let dto = LegacyMapper.user(row) else { return skip(.users) }
        var user = users[dto.remoteID]
        var created = false
        // A user created locally with the same email is linked instead of duplicated.
        if user == nil, let email = dto.email, let local = Session.findUser(email: email, in: context) {
            user = local
            local.remoteID = dto.remoteID
            users[dto.remoteID] = local
        }
        if user == nil {
            let new = AppUser(context: context)
            new.stampCreated()
            new.remoteID = dto.remoteID
            // Old passwords cannot be migrated: lock the account until an admin sets one.
            Session.setPassword(UUID().uuidString + UUID().uuidString, for: new)
            new.isActive = false
            users[dto.remoteID] = new
            user = new
            created = true
        }
        guard let user else { return }
        user.firstName = dto.firstName ?? user.firstName
        user.lastName = dto.lastName ?? user.lastName
        if let email = dto.email { user.email = email }
        user.phone = dto.phone ?? user.phone
        user.role = dto.role
        if dto.role == .plantManager, let name = dto.plantName {
            user.plant = plant(named: name)
        }
        record(.users, created)
        if !created { user.touch() }
    }

    private func importProject(_ row: LegacyRow) -> (NSManagedObject, String)? {
        guard let dto = LegacyMapper.project(row) else { skip(.projects); return nil }
        let (project, created) = upsert(Project.self, dto.remoteID, cache: &projects, resource: .projects)
        project.quantity = dto.quantity
        project.price = dto.price
        project.minutes = dto.minutes
        project.status = dto.status
        project.clientName = dto.clientName
        project.client = dto.clientName.flatMap { client(named: $0, create: false) }
        project.fabric = dto.fabric
        project.deliveryDate = dto.deliveryDate
        project.notes = dto.notes
        finish(project, created)
        guard project.photoData == nil, let path = dto.photoPath else { return nil }
        return (project, path)
    }

    private func importPendingCut(_ row: LegacyRow) {
        guard let dto = LegacyMapper.pendingCut(row) else { return skip(.pendingCuts) }
        let (order, created) = upsert(CutOrder.self, dto.remoteID, cache: &orders, resource: .pendingCuts)
        order.code = dto.code
        order.list = dto.list
        order.garment = dto.garment
        order.quantity = max(dto.quantity, Int64(order.assignedQuantity))
        order.unitPrice = dto.unitPrice
        order.internalDate = dto.internalDate
        order.clientDate = dto.clientDate
        order.editedBy = dto.editedBy
        order.client = dto.clientName.flatMap { client(named: $0, create: true) }
        order.style = dto.styleName.flatMap { style(named: $0) }
        finish(order, created)
    }

    private func importCut(_ row: LegacyRow) {
        guard let dto = LegacyMapper.cut(row) else { return skip(.cuts) }
        let (assignment, created) = upsert(Assignment.self, dto.remoteID, cache: &assignments, resource: .cuts)
        assignment.quantity = dto.quantity
        assignment.unitPrice = dto.unitPrice
        assignment.scheduledDate = dto.scheduledDate
        if assignment.cutReport == nil { assignment.cuttingStatus = dto.status }
        assignment.plant = dto.plantRemoteID.flatMap { plants[$0] }

        let order = assignment.order ?? findOrder(code: dto.code, list: dto.list) ?? makeOrder(for: dto)
        assignment.order = order
        // Fully assigned cuts disappear from getPendingCuts; keep the order consistent with its assignments.
        if order.quantity < Int64(order.assignedQuantity) { order.quantity = Int64(order.assignedQuantity) }
        if order.unitPrice == 0 { order.unitPrice = dto.unitPrice }
        finish(assignment, created)
    }

    private func importReport(_ row: LegacyRow) {
        guard let dto = LegacyMapper.report(row), let cutID = dto.cutRemoteID, let assignment = assignments[cutID] else {
            return skip(.reports)
        }
        // Exactly one cut report per assignment: later duplicates from the old server are ignored.
        if dto.kind == .cut, reports[dto.remoteID] == nil, let existing = assignment.cutReport, existing.remoteID != dto.remoteID {
            return skip(.reports)
        }
        let (report, created) = upsert(ProductionReport.self, dto.remoteID, cache: &reports, resource: .reports)
        report.kind = dto.kind
        report.assignment = assignment
        if let date = dto.createdAt { report.createdAt = date }
        report.authorName = report.authorName ?? "Sistema anterior"
        report.operators = dto.operators
        report.absences = dto.absences
        report.produced = dto.produced
        report.ironing = dto.ironing
        report.packing = dto.packing
        report.warehouse = dto.warehouse
        report.cutStatus = dto.cutStatus
        report.realQuantity = dto.realQuantity
        report.shipmentNumber = dto.shipmentNumber
        report.shippedQuantity = dto.shippedQuantity
        finish(report, created)
    }

    /// The cut report is the source of truth for the board status.
    private func syncCuttingStatus() {
        for assignment in assignments.values {
            if let status = assignment.cutReport?.cutStatus { assignment.cuttingStatus = status }
        }
    }

    // MARK: Lookups

    private func plant(named name: String) -> Plant? {
        let key = LegacyMapper.normalized(name)
        return plants.values.first { LegacyMapper.normalized($0.name) == key }
            ?? context.fetchAll(Plant.self, predicate: NSPredicate(format: "name ==[cd] %@", name)).first
    }

    private func client(named name: String, create: Bool) -> Client? {
        if let match = context.fetchAll(Client.self, predicate: NSPredicate(format: "name ==[cd] %@", name)).first { return match }
        guard create else { return nil }
        let client = Client(context: context)
        client.stampCreated()
        client.name = name
        return client
    }

    private func style(named name: String) -> Style {
        if let match = context.fetchAll(Style.self, predicate: NSPredicate(format: "name ==[cd] %@", name)).first { return match }
        let style = Style(context: context)
        style.stampCreated()
        style.name = name
        return style
    }

    private func findOrder(code: String?, list: String?) -> CutOrder? {
        guard let code else { return nil }
        let key = (LegacyMapper.normalized(code), LegacyMapper.normalized(list))
        return orders.values.first { LegacyMapper.normalized($0.code) == key.0 && LegacyMapper.normalized($0.list) == key.1 }
            ?? context.fetchAll(CutOrder.self, predicate: NSPredicate(format: "code ==[cd] %@ AND list ==[cd] %@", code, list ?? ""))
            .first
    }

    /// Cuts whose order no longer appears in getPendingCuts (fully assigned) still need an order.
    private func makeOrder(for cut: LegacyCut) -> CutOrder {
        let order = CutOrder(context: context)
        order.stampCreated()
        order.code = cut.code
        order.list = cut.list
        order.garment = cut.garment
        order.unitPrice = cut.unitPrice
        order.clientDate = cut.clientDate
        order.internalDate = cut.scheduledDate
        order.editedBy = "Sistema anterior"
        order.client = cut.clientName.flatMap { client(named: $0, create: true) }
        order.style = cut.styleName.flatMap { style(named: $0) }
        return order
    }

    // MARK: Upsert plumbing

    private func loadCaches() {
        func load<T: NSManagedObject>(_ type: T.Type, _ key: KeyPath<T, Int64>) -> [Int64: T] {
            let objects = context.fetchAll(type, predicate: NSPredicate(format: "remoteID != 0"))
            return Dictionary(objects.map { ($0[keyPath: key], $0) }, uniquingKeysWith: { first, _ in first })
        }
        plants = load(Plant.self, \.remoteID)
        clients = load(Client.self, \.remoteID)
        suppliers = load(Supplier.self, \.remoteID)
        styles = load(Style.self, \.remoteID)
        users = load(AppUser.self, \.remoteID)
        projects = load(Project.self, \.remoteID)
        orders = load(CutOrder.self, \.remoteID)
        assignments = load(Assignment.self, \.remoteID)
        reports = load(ProductionReport.self, \.remoteID)
        cachesLoaded = true
    }

    private func upsert<T: NSManagedObject & Timestamped>(
        _ type: T.Type, _ remoteID: Int64, cache: inout [Int64: T], resource: LegacyResource
    ) -> (T, Bool) {
        if let existing = cache[remoteID] { return (existing, false) }
        let entityName = String(describing: T.self)  // entity names match class names
        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! T
        object.stampCreated()
        object.setValue(remoteID, forKey: "remoteID")
        cache[remoteID] = object
        return (object, true)
    }

    private func finish(_ object: NSManagedObject & Timestamped, _ created: Bool) {
        if !created { object.touch() }
        let resource: LegacyResource =
            switch object {
            case is Plant: .plants
            case is Client: .clients
            case is Supplier: .suppliers
            case is Style: .styles
            case is Project: .projects
            case is CutOrder: .pendingCuts
            case is Assignment: .cuts
            case is ProductionReport: .reports
            default: .users
            }
        record(resource, created)
    }

    private func record(_ resource: LegacyResource, _ created: Bool) {
        if created { summary[resource].created += 1 } else { summary[resource].updated += 1 }
    }

    private func skip(_ resource: LegacyResource) { summary[resource].skipped += 1 }
}
