package com.nevutech.trama.core.domain

/** Plant-level constants used by the production calculator. */
data class CalculatorConstants(
    val minutesPerDay: Double = 0.0,
    val minutesPerWeek: Double = 0.0,
    val minutesPerMonth: Double = 0.0,
    val workDaysPerWeek: Double = 0.0,
    val workDaysPerMonth: Double = 0.0,
) {
    val isComplete: Boolean
        get() = listOf(minutesPerDay, minutesPerWeek, minutesPerMonth, workDaysPerWeek, workDaysPerMonth).all { it > 0 }
}

data class CalculatorInput(
    val quantity: Double = 0.0,
    val realMinutes: Double = 0.0,
    val clientMinutes: Double = 0.0,
    val operators: Double = 0.0,
    val internalUnitPrice: Double = 0.0,
    val pricePerStyle: Double = 0.0,
    val operatingExpenses: Double = 0.0,
    val lineOperators: Double = 0.0,
    val realDailyProduction: Double = 0.0,
)

/** Every value is null until the inputs it depends on are present, so the UI shows live partial results. */
data class CalculatorResult(
    val grossIncome: Double? = null,
    val netIncome: Double? = null,
    val pricePerRealMinute: Double? = null,
    val dailyGoal: Double? = null,
    val estimatedDays: Double? = null,
    val estimatedMonths: Double? = null,
    val weeklyProduction: Double? = null,
    val minuteEfficiency: Double? = null,
    val realProductionMinute: Double? = null,
)

object CalculatorEngine {
    fun compute(input: CalculatorInput, c: CalculatorConstants): CalculatorResult {
        var r = CalculatorResult()
        if (input.quantity > 0 && input.pricePerStyle > 0) {
            val gross = input.quantity * input.pricePerStyle
            r = r.copy(grossIncome = gross, netIncome = gross - input.operatingExpenses)
        }
        if (input.pricePerStyle > 0 && input.realMinutes > 0) {
            r = r.copy(pricePerRealMinute = input.pricePerStyle / input.realMinutes)
        }
        if (input.operators > 0 && c.minutesPerDay > 0 && input.realMinutes > 0) {
            val goal = input.operators * c.minutesPerDay / input.realMinutes
            r = r.copy(dailyGoal = goal)
            if (c.workDaysPerWeek > 0) r = r.copy(weeklyProduction = goal * c.workDaysPerWeek)
            if (input.quantity > 0 && goal > 0) {
                val days = input.quantity / goal
                r = r.copy(estimatedDays = days)
                if (c.workDaysPerMonth > 0) r = r.copy(estimatedMonths = days / c.workDaysPerMonth)
            }
        }
        if (input.clientMinutes > 0 && input.realMinutes > 0) {
            r = r.copy(minuteEfficiency = input.clientMinutes / input.realMinutes)
        }
        if (c.minutesPerDay > 0 && input.lineOperators > 0 && input.realDailyProduction > 0) {
            r = r.copy(realProductionMinute = c.minutesPerDay * input.lineOperators / input.realDailyProduction)
        }
        return r
    }
}
