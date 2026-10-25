import CoreData
import Foundation

/// All production writes go through here so business rules live in one place
/// (and the sync outbox has a single choke point: `saveTracked`).
struct ProductionService {
    let context: NSManagedObjectContext
    var author: String?

    enum ServiceError: LocalizedError {
        case cutReportExists
        case notAllowed
        case inUse(String)

        var errorDescription: String? {
            switch self {
            case .cutReportExists: String(localized: "Este corte ya tiene un reporte de corte. Edítalo en lugar de crear otro.")
            case .notAllowed: String(localized: "Tu puesto no permite esta acción.")
            case .inUse(let what): String(localized: "No se puede eliminar: \(what).")
            }
        }
    }

    // MARK: Orders

    @discardableResult
    func createOrder(
        code: String, list: String, garment: String, quantity: Int, unitPrice: Double,
        client: Client?, style: Style?, internalDate: Date?, clientDate: Date?, notes: String?
    ) throws -> CutOrder {
        let order = CutOrder(context: context)
        order.stampCreated()
        apply(
            to: order, code: code, list: list, garment: garment, quantity: quantity, unitPrice: unitPrice,
            client: client, style: style, internalDate: internalDate, clientDate: clientDate, notes: notes)
        try context.saveTracked()
        return order
    }

    func update(
        _ order: CutOrder, code: String, list: String, garment: String, quantity: Int, unitPrice: Double,
        client: Client?, style: Style?, internalDate: Date?, clientDate: Date?, notes: String?
    ) throws {
        apply(
            to: order, code: code, list: list, garment: garment, quantity: quantity, unitPrice: unitPrice,
            client: client, style: style, internalDate: internalDate, clientDate: clientDate, notes: notes)
        order.touch()
        try context.saveTracked()
    }

    private func apply(
        to order: CutOrder, code: String, list: String, garment: String, quantity: Int, unitPrice: Double,
        client: Client?, style: Style?, internalDate: Date?, clientDate: Date?, notes: String?
    ) {
        order.code = code.trimmingCharacters(in: .whitespaces)
        order.list = list.trimmingCharacters(in: .whitespaces)
        order.garment = garment.trimmingCharacters(in: .whitespaces)
        order.quantity = Int64(quantity)
        order.unitPrice = unitPrice
        order.client = client
        order.style = style
        order.internalDate = internalDate
        order.clientDate = clientDate
        order.notes = notes
        order.editedBy = author
    }

    // MARK: Assignment

    /// Assigns part (or all) of an order to a plant for a given month, enforcing remaining quantity
    /// and the plant's monthly capacity.
    @discardableResult
    func assign(order: CutOrder, to plant: Plant, quantity: Int, date: Date?) throws -> Assignment {
        let result = AssignmentRules.validate(
            quantity: quantity, unitPrice: order.unitPrice,
            remaining: order.remainingQuantity, date: date, ledger: plant.ledger
        )
        if case .failure(let error) = result { throw error }

        let assignment = Assignment(context: context)
        assignment.stampCreated()
        assignment.order = order
        assignment.plant = plant
        assignment.quantity = Int64(quantity)
        assignment.unitPrice = order.unitPrice
        assignment.scheduledDate = date
        assignment.cuttingStatus = .waiting
        order.editedBy = author
        order.touch()
        try context.saveTracked()
        return assignment
    }

    func unassign(_ assignment: Assignment) throws {
        if !(assignment.reports as? Set<ProductionReport> ?? []).isEmpty {
            throw ServiceError.inUse(String(localized: "el corte ya tiene reportes"))
        }
        context.delete(assignment)
        try context.saveTracked()
    }

    // MARK: Reports

    struct PlantReportInput {
        var operators = 0, absences = 0, produced = 0, ironing = 0, packing = 0, warehouse = 0
    }

    @discardableResult
    func addPlantReport(
        _ input: PlantReportInput, to assignment: Assignment, editing report: ProductionReport? = nil
    ) throws -> ProductionReport {
        let r = report ?? newReport(.plant, on: assignment)
        r.operators = Int64(input.operators)
        r.absences = Int64(input.absences)
        r.produced = Int64(input.produced)
        r.ironing = Int64(input.ironing)
        r.packing = Int64(input.packing)
        r.warehouse = Int64(input.warehouse)
        return try finish(r, on: assignment)
    }

    /// Only one cut report per assignment (legacy rule). Creating a second one fails;
    /// editing the existing one is allowed.
    @discardableResult
    func setCutReport(
        status: CutStatus, realQuantity: Int, on assignment: Assignment, editing report: ProductionReport? = nil
    ) throws -> ProductionReport {
        if report == nil, assignment.cutReport != nil { throw ServiceError.cutReportExists }
        let r = report ?? newReport(.cut, on: assignment)
        r.cutStatus = status
        r.realQuantity = Int64(max(0, realQuantity))
        assignment.cuttingStatus = status
        return try finish(r, on: assignment)
    }

    /// Kanban move: updates the single cut report (creating it if needed) keeping the real quantity.
    func move(_ assignment: Assignment, to status: CutStatus) throws {
        let current = assignment.cutReport
        try setCutReport(status: status, realQuantity: Int(current?.realQuantity ?? 0), on: assignment, editing: current)
    }

    @discardableResult
    func addShipmentReport(
        number: String, quantity: Int, to assignment: Assignment, editing report: ProductionReport? = nil
    ) throws -> ProductionReport {
        let r = report ?? newReport(.shipment, on: assignment)
        r.shipmentNumber = number.trimmingCharacters(in: .whitespaces)
        r.shippedQuantity = Int64(max(0, quantity))
        return try finish(r, on: assignment)
    }

    func delete(_ report: ProductionReport) throws {
        if report.kind == .cut, let assignment = report.assignment { assignment.cuttingStatus = .waiting }
        context.delete(report)
        try context.saveTracked()
    }

    private func newReport(_ kind: ReportKind, on assignment: Assignment) -> ProductionReport {
        let r = ProductionReport(context: context)
        r.stampCreated()
        r.kind = kind
        r.authorName = author
        r.assignment = assignment
        return r
    }

    private func finish(_ report: ProductionReport, on assignment: Assignment) throws -> ProductionReport {
        report.touch()
        assignment.touch()
        try context.saveTracked()
        return report
    }

    // MARK: Guarded deletes

    func delete(_ plant: Plant) throws {
        if !(plant.assignments as? Set<Assignment> ?? []).isEmpty {
            throw ServiceError.inUse(String(localized: "la planta tiene cortes asignados"))
        }
        context.delete(plant)
        try context.saveTracked()
    }

    func delete(_ client: Client) throws {
        if !(client.orders as? Set<CutOrder> ?? []).isEmpty { throw ServiceError.inUse(String(localized: "el cliente tiene cortes")) }
        context.delete(client)
        try context.saveTracked()
    }

    func delete(_ order: CutOrder) throws {
        if order.assignmentList.contains(where: { !($0.reports as? Set<ProductionReport> ?? []).isEmpty }) {
            throw ServiceError.inUse(String(localized: "el corte ya tiene reportes de producción"))
        }
        context.delete(order)
        try context.saveTracked()
    }

    func delete(_ object: NSManagedObject) throws {
        context.delete(object)
        try context.saveTracked()
    }
}
