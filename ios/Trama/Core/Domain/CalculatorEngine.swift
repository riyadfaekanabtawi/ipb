import Foundation

/// Plant-level constants used by the production calculator. Persisted in UserDefaults
/// under the same keys the legacy app used, so values survive the migration.
struct CalculatorConstants: Equatable, Codable {
    var minutesPerDay: Double = 0
    var minutesPerWeek: Double = 0
    var minutesPerMonth: Double = 0
    var workDaysPerWeek: Double = 0
    var workDaysPerMonth: Double = 0

    var isComplete: Bool {
        [minutesPerDay, minutesPerWeek, minutesPerMonth, workDaysPerWeek, workDaysPerMonth].allSatisfy { $0 > 0 }
    }

    enum Key {
        static let minutesPerDay = "minutos_dia_operario"
        static let minutesPerWeek = "minutos_semana_operario"
        static let minutesPerMonth = "minutos_mes_operario"
        static let workDaysPerMonth = "dias_mes"
        static let workDaysPerWeek = "dias_semana"
    }

    /// Legacy builds stored these as strings; accept both strings and numbers.
    static func load(from defaults: UserDefaults = .standard) -> CalculatorConstants {
        func read(_ key: String) -> Double {
            if let string = defaults.string(forKey: key) { return Double(string.replacingOccurrences(of: ",", with: "")) ?? 0 }
            return defaults.double(forKey: key)
        }
        return CalculatorConstants(
            minutesPerDay: read(Key.minutesPerDay),
            minutesPerWeek: read(Key.minutesPerWeek),
            minutesPerMonth: read(Key.minutesPerMonth),
            workDaysPerWeek: read(Key.workDaysPerWeek),
            workDaysPerMonth: read(Key.workDaysPerMonth)
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(minutesPerDay, forKey: Key.minutesPerDay)
        defaults.set(minutesPerWeek, forKey: Key.minutesPerWeek)
        defaults.set(minutesPerMonth, forKey: Key.minutesPerMonth)
        defaults.set(workDaysPerWeek, forKey: Key.workDaysPerWeek)
        defaults.set(workDaysPerMonth, forKey: Key.workDaysPerMonth)
    }
}

struct CalculatorInput: Equatable {
    var quantity: Double = 0
    var realMinutes: Double = 0
    var clientMinutes: Double = 0
    var operators: Double = 0
    var internalUnitPrice: Double = 0
    var pricePerStyle: Double = 0
    var operatingExpenses: Double = 0

    // "Minuto real de producción" section.
    var lineOperators: Double = 0
    var realDailyProduction: Double = 0
}

/// Results of the production calculator. Every value is optional: it is `nil` until the inputs
/// it depends on are present, so the UI can show live partial results instead of crashing
/// (the legacy screen force-unwrapped and divided by zero).
struct CalculatorResult: Equatable {
    var grossIncome: Double?
    var netIncome: Double?
    var pricePerRealMinute: Double?
    var dailyGoal: Double?
    var estimatedDays: Double?
    var estimatedMonths: Double?
    var weeklyProduction: Double?
    var minuteEfficiency: Double?
    var realProductionMinute: Double?
}

enum CalculatorEngine {
    static func compute(_ input: CalculatorInput, constants c: CalculatorConstants) -> CalculatorResult {
        var r = CalculatorResult()

        if input.quantity > 0, input.pricePerStyle > 0 {
            r.grossIncome = input.quantity * input.pricePerStyle
            r.netIncome = r.grossIncome.map { $0 - input.operatingExpenses }
        }
        if input.pricePerStyle > 0, input.realMinutes > 0 {
            r.pricePerRealMinute = input.pricePerStyle / input.realMinutes
        }
        if input.operators > 0, c.minutesPerDay > 0, input.realMinutes > 0 {
            let goal = input.operators * c.minutesPerDay / input.realMinutes
            r.dailyGoal = goal
            if c.workDaysPerWeek > 0 { r.weeklyProduction = goal * c.workDaysPerWeek }
            if input.quantity > 0, goal > 0 {
                let days = input.quantity / goal
                r.estimatedDays = days
                // Legacy divided price-per-minute by 20 here; months are working days / days per month.
                if c.workDaysPerMonth > 0 { r.estimatedMonths = days / c.workDaysPerMonth }
            }
        }
        if input.clientMinutes > 0, input.realMinutes > 0 {
            r.minuteEfficiency = input.clientMinutes / input.realMinutes
        }
        if c.minutesPerDay > 0, input.lineOperators > 0, input.realDailyProduction > 0 {
            r.realProductionMinute = c.minutesPerDay * input.lineOperators / input.realDailyProduction
        }
        return r
    }
}
