import Foundation

/// Pure production math, kept free of Core Data so it is trivially testable.
/// These rules reproduce what the legacy Rails backend computed server side.

/// A snapshot of one report, decoupled from Core Data.
struct ReportSnapshot: Equatable {
    var kind: ReportKind
    var createdAt: Date
    var operators: Int = 0
    var absences: Int = 0
    var produced: Int = 0
    var ironing: Int = 0
    var packing: Int = 0
    var warehouse: Int = 0
    var cutStatus: CutStatus? = nil
    var realQuantity: Int = 0
    var shippedQuantity: Int = 0
}

/// Live counters for an assignment (a cut assigned to a plant), derived from its reports.
struct AssignmentMetrics: Equatable {
    var quantity: Int
    var unitPrice: Double

    /// Real quantity cut, from the (single) cut report. 0 until reported.
    var realCut: Int = 0
    var cutStatus: CutStatus = .waiting

    // Latest plant report snapshot.
    var operators: Int = 0
    var absences: Int = 0
    var produced: Int = 0
    var ironing: Int = 0
    var packing: Int = 0
    var warehouse: Int = 0

    /// Sum of all shipment reports.
    var shipped: Int = 0

    var revenue: Double { Double(quantity) * unitPrice }

    /// Garments the shipment flow is measured against: the real cut once known, else the planned quantity.
    var shippingBase: Int { realCut > 0 ? realCut : quantity }

    var toShip: Int { max(0, shippingBase - shipped) }

    var shippingProgress: Double {
        guard shippingBase > 0 else { return 0 }
        return min(1, Double(shipped) / Double(shippingBase))
    }

    var productionProgress: Double {
        guard shippingBase > 0 else { return 0 }
        return min(1, Double(produced) / Double(shippingBase))
    }

    var isComplete: Bool { shippingBase > 0 && toShip == 0 }

    init(quantity: Int, unitPrice: Double, reports: [ReportSnapshot]) {
        self.quantity = quantity
        self.unitPrice = unitPrice
        let sorted = reports.sorted { $0.createdAt < $1.createdAt }
        if let cut = sorted.last(where: { $0.kind == .cut }) {
            realCut = cut.realQuantity
            cutStatus = cut.cutStatus ?? .waiting
        }
        if let plant = sorted.last(where: { $0.kind == .plant }) {
            operators = plant.operators
            absences = plant.absences
            produced = plant.produced
            ironing = plant.ironing
            packing = plant.packing
            warehouse = plant.warehouse
        }
        shipped = sorted.filter { $0.kind == .shipment }.reduce(0) { $0 + $1.shippedQuantity }
    }
}

/// Aggregate totals shown on the production reports screen (legacy `getTotals`).
struct ProductionTotals: Equatable {
    var shipped = 0
    var quantity = 0
    var produced = 0
    var ironing = 0
    var packing = 0
    var warehouse = 0
    var toShip = 0
    var revenue: Double = 0

    init(_ metrics: [AssignmentMetrics] = []) {
        for m in metrics {
            shipped += m.shipped
            quantity += m.quantity
            produced += m.produced
            ironing += m.ironing
            packing += m.packing
            warehouse += m.warehouse
            toShip += m.toShip
            revenue += m.revenue
        }
    }
}

/// Monthly capacity bookkeeping for a plant. Capacity is measured in currency per month,
/// exactly like the legacy `max_capacity` / `<month>_min` fields.
struct CapacityLedger {
    struct Booking { var date: Date; var amount: Double }

    var maxCapacity: Double
    var bookings: [Booking]
    var calendar: Calendar = .current

    func used(inMonthOf date: Date) -> Double {
        bookings
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    func available(inMonthOf date: Date) -> Double { maxCapacity - used(inMonthOf: date) }

    func utilization(inMonthOf date: Date) -> Double {
        guard maxCapacity > 0 else { return 0 }
        return used(inMonthOf: date) / maxCapacity
    }

    /// Used capacity for each month (1...12) of the given year.
    func monthlyUsage(year: Int) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for month in 1...12 { result[month] = 0 }
        for booking in bookings where calendar.component(.year, from: booking.date) == year {
            result[calendar.component(.month, from: booking.date), default: 0] += booking.amount
        }
        return result
    }
}

enum AssignmentError: LocalizedError, Equatable {
    case missingDate
    case invalidQuantity
    case exceedsRemaining(remaining: Int)
    case exceedsCapacity(available: Double)

    var errorDescription: String? {
        switch self {
        case .missingDate: "Elige una fecha en el calendario."
        case .invalidQuantity: "Ingresa una cantidad mayor a cero."
        case .exceedsRemaining(let remaining):
            "La cantidad no puede ser mayor a lo que falta por asignar (\(remaining.formatted()))."
        case .exceedsCapacity(let available):
            "La planta ha llegado a su capacidad máxima para ese mes. Disponible: \(available.formatted(.currency(code: "MXN")))."
        }
    }
}

enum AssignmentRules {
    /// Validates assigning `quantity` garments of an order to a plant, reproducing the legacy checks
    /// (quantity ≤ pending, and the plant's monthly capacity in currency).
    static func validate(
        quantity: Int,
        unitPrice: Double,
        remaining: Int,
        date: Date?,
        ledger: CapacityLedger
    ) -> Result<Double, AssignmentError> {
        guard let date else { return .failure(.missingDate) }
        guard quantity > 0 else { return .failure(.invalidQuantity) }
        guard quantity <= remaining else { return .failure(.exceedsRemaining(remaining: remaining)) }
        let total = Double(quantity) * unitPrice
        let available = ledger.available(inMonthOf: date)
        guard total <= available + 0.000_1 else { return .failure(.exceedsCapacity(available: max(0, available))) }
        return .success(total)
    }
}

enum UrgencyPolicy {
    /// An assignment is urgent when garments are still pending shipment and the client
    /// delivery date is within `windowDays` (or already overdue).
    static func isUrgent(toShip: Int, clientDate: Date?, now: Date = .now, windowDays: Int, calendar: Calendar = .current) -> Bool {
        guard toShip > 0, let clientDate else { return false }
        let startOfToday = calendar.startOfDay(for: now)
        guard let limit = calendar.date(byAdding: .day, value: windowDays, to: startOfToday) else { return false }
        return clientDate < limit
    }

    static func daysLeft(until date: Date?, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let date else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day
    }
}
