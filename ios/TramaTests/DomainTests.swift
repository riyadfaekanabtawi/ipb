import Foundation
import Testing

@testable import Trama

@Suite("Production math")
struct ProductionMathTests {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func metricsUseLatestPlantReportAndSumShipments() {
        let reports = [
            ReportSnapshot(kind: .plant, createdAt: t0, operators: 10, produced: 100),
            ReportSnapshot(kind: .plant, createdAt: t0.addingTimeInterval(60), operators: 12, produced: 250, warehouse: 40),
            ReportSnapshot(kind: .shipment, createdAt: t0, shippedQuantity: 30),
            ReportSnapshot(kind: .shipment, createdAt: t0.addingTimeInterval(5), shippedQuantity: 20),
            ReportSnapshot(kind: .cut, createdAt: t0, cutStatus: .ready, realQuantity: 480),
        ]
        let m = AssignmentMetrics(quantity: 500, unitPrice: 10, reports: reports)
        #expect(m.produced == 250)
        #expect(m.operators == 12)
        #expect(m.warehouse == 40)
        #expect(m.shipped == 50)
        #expect(m.realCut == 480)
        #expect(m.cutStatus == .ready)
        #expect(m.shippingBase == 480)
        #expect(m.toShip == 430)
        #expect(m.revenue == 5_000)
    }

    @Test func toShipFallsBackToPlannedQuantityAndNeverGoesNegative() {
        let m = AssignmentMetrics(
            quantity: 100, unitPrice: 1,
            reports: [
                ReportSnapshot(kind: .shipment, createdAt: t0, shippedQuantity: 150)
            ])
        #expect(m.shippingBase == 100)
        #expect(m.toShip == 0)
        #expect(m.isComplete)
        #expect(m.shippingProgress == 1)
    }

    @Test func totalsAggregate() {
        let a = AssignmentMetrics(
            quantity: 100, unitPrice: 2, reports: [ReportSnapshot(kind: .plant, createdAt: t0, produced: 40, ironing: 5)])
        let b = AssignmentMetrics(
            quantity: 50, unitPrice: 4, reports: [ReportSnapshot(kind: .shipment, createdAt: t0, shippedQuantity: 10)])
        let totals = ProductionTotals([a, b])
        #expect(totals.quantity == 150)
        #expect(totals.produced == 40)
        #expect(totals.ironing == 5)
        #expect(totals.shipped == 10)
        #expect(totals.toShip == 140)
        #expect(totals.revenue == 400)
    }
}

@Suite("Capacity and assignment rules")
struct CapacityTests {
    let cal = Calendar(identifier: .gregorian)
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

    @Test func ledgerSumsOnlyTheSameMonth() {
        let ledger = CapacityLedger(
            maxCapacity: 1_000,
            bookings: [
                .init(date: date(2026, 3, 2), amount: 300),
                .init(date: date(2026, 3, 28), amount: 200),
                .init(date: date(2026, 4, 1), amount: 999),
            ], calendar: cal)
        #expect(ledger.used(inMonthOf: date(2026, 3, 15)) == 500)
        #expect(ledger.available(inMonthOf: date(2026, 3, 15)) == 500)
        #expect(ledger.utilization(inMonthOf: date(2026, 4, 10)) == 0.999)
        #expect(ledger.monthlyUsage(year: 2026)[3] == 500)
        #expect(ledger.monthlyUsage(year: 2026)[5] == 0)
    }

    @Test func validateRejectsOverCapacity() {
        let ledger = CapacityLedger(maxCapacity: 1_000, bookings: [.init(date: date(2026, 3, 2), amount: 900)], calendar: cal)
        let result = AssignmentRules.validate(quantity: 20, unitPrice: 10, remaining: 50, date: date(2026, 3, 9), ledger: ledger)
        #expect(result == .failure(.exceedsCapacity(available: 100)))
    }

    @Test func validateRejectsMoreThanRemaining() {
        let ledger = CapacityLedger(maxCapacity: 1_000_000, bookings: [], calendar: cal)
        #expect(
            AssignmentRules.validate(quantity: 60, unitPrice: 1, remaining: 50, date: .now, ledger: ledger)
                == .failure(.exceedsRemaining(remaining: 50)))
        #expect(
            AssignmentRules.validate(quantity: 0, unitPrice: 1, remaining: 50, date: .now, ledger: ledger) == .failure(.invalidQuantity))
        #expect(AssignmentRules.validate(quantity: 10, unitPrice: 1, remaining: 50, date: nil, ledger: ledger) == .failure(.missingDate))
    }

    @Test func validateAcceptsAndReturnsTotal() {
        let ledger = CapacityLedger(maxCapacity: 1_000, bookings: [], calendar: cal)
        #expect(
            AssignmentRules.validate(quantity: 10, unitPrice: 100, remaining: 10, date: date(2026, 1, 1), ledger: ledger) == .success(1_000)
        )
    }
}

@Suite("Urgency")
struct UrgencyTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func urgentWhenPendingAndDueSoon() {
        let soon = now.addingTimeInterval(3 * 86_400)
        let later = now.addingTimeInterval(30 * 86_400)
        let past = now.addingTimeInterval(-86_400)
        #expect(UrgencyPolicy.isUrgent(toShip: 10, clientDate: soon, now: now, windowDays: 7))
        #expect(UrgencyPolicy.isUrgent(toShip: 10, clientDate: past, now: now, windowDays: 7))
        #expect(!UrgencyPolicy.isUrgent(toShip: 10, clientDate: later, now: now, windowDays: 7))
        #expect(!UrgencyPolicy.isUrgent(toShip: 0, clientDate: soon, now: now, windowDays: 7))
        #expect(!UrgencyPolicy.isUrgent(toShip: 10, clientDate: nil, now: now, windowDays: 7))
    }
}

@Suite("Calculator")
struct CalculatorTests {
    let constants = CalculatorConstants(
        minutesPerDay: 480, minutesPerWeek: 2_400, minutesPerMonth: 9_600, workDaysPerWeek: 5, workDaysPerMonth: 20)

    @Test func fullComputation() {
        var input = CalculatorInput()
        input.quantity = 4_000
        input.realMinutes = 12
        input.clientMinutes = 15
        input.operators = 30
        input.pricePerStyle = 60
        input.operatingExpenses = 40_000
        let r = CalculatorEngine.compute(input, constants: constants)
        #expect(r.grossIncome == 240_000)
        #expect(r.netIncome == 200_000)
        #expect(r.pricePerRealMinute == 5)
        #expect(r.dailyGoal == 1_200)
        #expect(r.weeklyProduction == 6_000)
        #expect(r.estimatedDays! > 3.33 && r.estimatedDays! < 3.34)
        #expect(r.estimatedMonths! > 0.166 && r.estimatedMonths! < 0.167)
        #expect(r.minuteEfficiency == 1.25)
    }

    @Test func missingInputsYieldNilInsteadOfCrashing() {
        let r = CalculatorEngine.compute(CalculatorInput(), constants: CalculatorConstants())
        #expect(r == CalculatorResult())
    }

    @Test func realProductionMinute() {
        var input = CalculatorInput()
        input.lineOperators = 20
        input.realDailyProduction = 800
        #expect(CalculatorEngine.compute(input, constants: constants).realProductionMinute == 12)
    }

    @Test func legacyStringConstantsAreRead() {
        let defaults = UserDefaults(suiteName: "calc-test-\(UUID())")!
        defaults.set("480", forKey: CalculatorConstants.Key.minutesPerDay)
        defaults.set("1,200", forKey: CalculatorConstants.Key.minutesPerWeek)
        let c = CalculatorConstants.load(from: defaults)
        #expect(c.minutesPerDay == 480)
        #expect(c.minutesPerWeek == 1_200)
    }
}

@Suite("Enums")
struct EnumTests {
    @Test func legacyCutStatusStrings() {
        #expect(CutStatus(legacy: "En Mesa de Corte") == .onTable)
        #expect(CutStatus(legacy: "listo para confeccionar") == .ready)
        #expect(CutStatus(legacy: "en espera") == .waiting)
        #expect(CutStatus(legacy: nil) == .waiting)
    }

    @Test func rolePermissionsMirrorLegacyMenu() {
        #expect(Role.admin.sections == AppSection.allCases)
        #expect(Role.plantManager.creatableReports == [.plant])
        #expect(Role.shippingManager.sections.contains(.shipments))
        #expect(!Role.plantManager.sections.contains(.orders))
        #expect(Role.cutManager.landing == .orders)
    }
}
