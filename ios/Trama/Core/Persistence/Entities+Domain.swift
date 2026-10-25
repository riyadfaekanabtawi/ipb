import CoreData
import Foundation

// Convenience accessors over the Xcode-generated NSManagedObject classes.
// Generated attributes are optional; these expose safe, non-optional values to the UI.

/// Common bookkeeping for every entity.
protocol Timestamped: NSManagedObject {
    var id: UUID? { get set }
    var createdAt: Date? { get set }
    var updatedAt: Date? { get set }
}

extension Timestamped {
    func stampCreated() {
        let now = Date()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = now }
        updatedAt = now
    }

    func touch() { updatedAt = Date() }
}

extension Plant: Timestamped {}
extension Client: Timestamped {}
extension Supplier: Timestamped {}
extension Style: Timestamped {}
extension CutOrder: Timestamped {}
extension Assignment: Timestamped {}
extension ProductionReport: Timestamped {}
extension Project: Timestamped {}
extension AppUser: Timestamped {}

// MARK: - Plant

extension Plant {
    var displayName: String { name ?? "Planta" }

    var assignmentList: [Assignment] {
        (assignments as? Set<Assignment> ?? []).sorted { ($0.scheduledDate ?? .distantPast) < ($1.scheduledDate ?? .distantPast) }
    }

    var ledger: CapacityLedger {
        CapacityLedger(
            maxCapacity: maxCapacity,
            bookings: assignmentList.compactMap { a in
                a.scheduledDate.map { CapacityLedger.Booking(date: $0, amount: a.metrics.revenue) }
            }
        )
    }
}

// MARK: - Client / Supplier / Contact

extension Client {
    var displayName: String { name ?? "Cliente" }
    var contactList: [Contact] { (contacts as? Set<Contact> ?? []).sorted { $0.sortIndex < $1.sortIndex } }
    var orderList: [CutOrder] {
        (orders as? Set<CutOrder> ?? []).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
}

extension Supplier {
    var displayName: String { name ?? "Proveedor" }
    var contactList: [Contact] { (contacts as? Set<Contact> ?? []).sorted { $0.sortIndex < $1.sortIndex } }
}

extension Contact {
    var isEmpty: Bool {
        [name, role, email, phone].allSatisfy { ($0 ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - Style

extension Style {
    var displayName: String { name ?? "Estilo" }
    var orderList: [CutOrder] { (orders as? Set<CutOrder> ?? []).sorted { ($0.code ?? "") < ($1.code ?? "") } }

    /// Number of assignments of this style per plant (legacy "Estilo asignado a plantas").
    var plantDistribution: [(plant: Plant, count: Int)] {
        var counts: [NSManagedObjectID: (Plant, Int)] = [:]
        for order in orderList {
            for assignment in order.assignmentList {
                guard let plant = assignment.plant else { continue }
                counts[plant.objectID, default: (plant, 0)].1 += 1
            }
        }
        return counts.values.map { (plant: $0.0, count: $0.1) }.sorted { $0.plant.displayName < $1.plant.displayName }
    }
}

// MARK: - CutOrder

extension CutOrder {
    var displayCode: String { code?.isEmpty == false ? code! : "Sin código" }
    var clientName: String { client?.displayName ?? "Sin cliente" }
    var styleName: String { style?.displayName ?? "Sin estilo" }

    var assignmentList: [Assignment] {
        (assignments as? Set<Assignment> ?? []).sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    var assignedQuantity: Int { assignmentList.reduce(0) { $0 + Int($1.quantity) } }
    var remainingQuantity: Int { max(0, Int(quantity) - assignedQuantity) }
    var revenue: Double { Double(quantity) * unitPrice }

    var assignmentState: OrderAssignmentState {
        if assignedQuantity == 0 { return .unassigned }
        return remainingQuantity == 0 ? .assigned : .partial
    }

    var searchableText: String {
        [code, list, garment, client?.name, style?.name, notes].compactMap { $0 }.joined(separator: " ").lowercased()
    }
}

// MARK: - Assignment

extension Assignment {
    var cuttingStatus: CutStatus {
        get { CutStatus(rawValue: cuttingStatusRaw ?? "") ?? .waiting }
        set { cuttingStatusRaw = newValue.rawValue }
    }

    var reportList: [ProductionReport] {
        (reports as? Set<ProductionReport> ?? []).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var cutReport: ProductionReport? { reportList.first { $0.kind == .cut } }

    var metrics: AssignmentMetrics {
        AssignmentMetrics(quantity: Int(quantity), unitPrice: unitPrice, reports: reportList.map(\.snapshot))
    }

    var plantName: String { plant?.displayName ?? "Sin planta" }
    var title: String { order?.displayCode ?? "Corte" }

    func isUrgent(windowDays: Int, now: Date = .now) -> Bool {
        UrgencyPolicy.isUrgent(toShip: metrics.toShip, clientDate: order?.clientDate, now: now, windowDays: windowDays)
    }

    var searchableText: String {
        [order?.searchableText, plant?.name, cuttingStatus.title].compactMap { $0 }.joined(separator: " ").lowercased()
    }
}

// MARK: - ProductionReport

extension ProductionReport {
    var kind: ReportKind {
        get { ReportKind(rawValue: kindRaw ?? "") ?? .plant }
        set { kindRaw = newValue.rawValue }
    }

    var cutStatus: CutStatus? {
        get { cutStatusRaw.flatMap(CutStatus.init(rawValue:)) }
        set { cutStatusRaw = newValue?.rawValue }
    }

    var snapshot: ReportSnapshot {
        ReportSnapshot(
            kind: kind,
            createdAt: createdAt ?? .distantPast,
            operators: Int(operators),
            absences: Int(absences),
            produced: Int(produced),
            ironing: Int(ironing),
            packing: Int(packing),
            warehouse: Int(warehouse),
            cutStatus: cutStatus,
            realQuantity: Int(realQuantity),
            shippedQuantity: Int(shippedQuantity)
        )
    }

    var summary: String {
        switch kind {
        case .plant:
            "\(Fmt.int(Int(produced))) producidas · \(Fmt.int(Int(operators))) operarios · \(Fmt.int(Int(absences))) faltas"
        case .cut:
            "\(cutStatus?.title ?? "—") · \(Fmt.int(Int(realQuantity))) cortadas"
        case .shipment:
            "Envío #\(shipmentNumber ?? "—") · \(Fmt.int(Int(shippedQuantity))) prendas"
        }
    }
}

// MARK: - Project

extension Project {
    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw ?? "") ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var total: Double { Double(quantity) * price }
    var displayClient: String { client?.displayName ?? clientName ?? "Sin cliente" }
}

// MARK: - AppUser

extension AppUser {
    var role: Role {
        get { Role(rawValue: roleRaw ?? "") ?? .plantManager }
        set { roleRaw = newValue.rawValue }
    }

    var fullName: String {
        let full = [firstName, lastName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (email ?? "Usuario") : full
    }
}
