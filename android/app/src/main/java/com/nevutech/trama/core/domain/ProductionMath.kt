package com.nevutech.trama.core.domain

import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit

// Pure production math, free of Room so it is trivially testable.
// Port of ios/Trama/Core/Domain/ProductionMath.swift; rules in docs/DOMAIN.md.

/** A snapshot of one report, decoupled from persistence. */
data class ReportSnapshot(
    val kind: ReportKind,
    val createdAt: Long,
    val operators: Int = 0,
    val absences: Int = 0,
    val produced: Int = 0,
    val ironing: Int = 0,
    val packing: Int = 0,
    val warehouse: Int = 0,
    val cutStatus: CutStatus? = null,
    val realQuantity: Int = 0,
    val shippedQuantity: Int = 0,
)

/** Live counters for an assignment (a cut assigned to a plant), derived from its reports. */
data class AssignmentMetrics(
    val quantity: Int,
    val unitPrice: Double,
    /** Real quantity cut, from the (single) cut report. 0 until reported. */
    val realCut: Int = 0,
    val cutStatus: CutStatus = CutStatus.Waiting,
    val operators: Int = 0,
    val absences: Int = 0,
    val produced: Int = 0,
    val ironing: Int = 0,
    val packing: Int = 0,
    val warehouse: Int = 0,
    /** Sum of all shipment reports. */
    val shipped: Int = 0,
) {
    val revenue: Double get() = quantity * unitPrice

    /** Garments shipments are measured against: the real cut once known, else the planned quantity. */
    val shippingBase: Int get() = if (realCut > 0) realCut else quantity
    val toShip: Int get() = maxOf(0, shippingBase - shipped)
    val shippingProgress: Double get() = if (shippingBase > 0) minOf(1.0, shipped.toDouble() / shippingBase) else 0.0
    val productionProgress: Double get() = if (shippingBase > 0) minOf(1.0, produced.toDouble() / shippingBase) else 0.0
    val isComplete: Boolean get() = shippingBase > 0 && toShip == 0

    companion object {
        fun of(quantity: Int, unitPrice: Double, reports: List<ReportSnapshot>): AssignmentMetrics {
            val sorted = reports.sortedBy { it.createdAt }
            val cut = sorted.lastOrNull { it.kind == ReportKind.Cut }
            val plant = sorted.lastOrNull { it.kind == ReportKind.Plant }
            return AssignmentMetrics(
                quantity = quantity,
                unitPrice = unitPrice,
                realCut = cut?.realQuantity ?: 0,
                cutStatus = cut?.cutStatus ?: CutStatus.Waiting,
                operators = plant?.operators ?: 0,
                absences = plant?.absences ?: 0,
                produced = plant?.produced ?: 0,
                ironing = plant?.ironing ?: 0,
                packing = plant?.packing ?: 0,
                warehouse = plant?.warehouse ?: 0,
                shipped = sorted.filter { it.kind == ReportKind.Shipment }.sumOf { it.shippedQuantity },
            )
        }
    }
}

/** Aggregate totals shown on the production reports screen (legacy `getTotals`). */
data class ProductionTotals(
    val shipped: Int = 0,
    val quantity: Int = 0,
    val produced: Int = 0,
    val ironing: Int = 0,
    val packing: Int = 0,
    val warehouse: Int = 0,
    val toShip: Int = 0,
    val revenue: Double = 0.0,
) {
    companion object {
        fun of(metrics: List<AssignmentMetrics>) = ProductionTotals(
            shipped = metrics.sumOf { it.shipped },
            quantity = metrics.sumOf { it.quantity },
            produced = metrics.sumOf { it.produced },
            ironing = metrics.sumOf { it.ironing },
            packing = metrics.sumOf { it.packing },
            warehouse = metrics.sumOf { it.warehouse },
            toShip = metrics.sumOf { it.toShip },
            revenue = metrics.sumOf { it.revenue },
        )
    }
}

/** Monthly capacity bookkeeping for a plant. Capacity is money per calendar month. */
data class CapacityLedger(val maxCapacity: Double, val bookings: List<Booking>) {
    data class Booking(val date: LocalDate, val amount: Double)

    fun used(month: YearMonth): Double = bookings.filter { YearMonth.from(it.date) == month }.sumOf { it.amount }
    fun available(month: YearMonth): Double = maxCapacity - used(month)
    fun utilization(month: YearMonth): Double = if (maxCapacity > 0) used(month) / maxCapacity else 0.0

    /** Used capacity for each month (1..12) of the given year. */
    fun monthlyUsage(year: Int): Map<Int, Double> {
        val result = (1..12).associateWith { 0.0 }.toMutableMap()
        bookings.filter { it.date.year == year }.forEach { result[it.date.monthValue] = result.getValue(it.date.monthValue) + it.amount }
        return result
    }
}

sealed class AssignmentError(message: String) : Exception(message) {
    data object MissingDate : AssignmentError("Elige una fecha en el calendario.")
    data object InvalidQuantity : AssignmentError("Ingresa una cantidad mayor a cero.")
    data class ExceedsRemaining(val remaining: Int) :
        AssignmentError("La cantidad no puede ser mayor a lo que falta por asignar (${Fmt.int(remaining)}).")
    data class ExceedsCapacity(val available: Double) :
        AssignmentError("La planta ha llegado a su capacidad máxima para ese mes. Disponible: ${Fmt.money(available)}.")
}

object AssignmentRules {
    /**
     * Validates assigning [quantity] garments of an order to a plant: quantity ≤ pending and the
     * plant's monthly capacity in currency. Returns the assignment value on success.
     */
    fun validate(quantity: Int, unitPrice: Double, remaining: Int, date: LocalDate?, ledger: CapacityLedger): Result<Double> {
        if (date == null) return Result.failure(AssignmentError.MissingDate)
        if (quantity <= 0) return Result.failure(AssignmentError.InvalidQuantity)
        if (quantity > remaining) return Result.failure(AssignmentError.ExceedsRemaining(remaining))
        val total = quantity * unitPrice
        val available = ledger.available(YearMonth.from(date))
        if (total > available + 0.0001) return Result.failure(AssignmentError.ExceedsCapacity(maxOf(0.0, available)))
        return Result.success(total)
    }
}

object UrgencyPolicy {
    /** Urgent when garments are still pending shipment and the client date is within [windowDays] or overdue. */
    fun isUrgent(toShip: Int, clientDate: LocalDate?, today: LocalDate = LocalDate.now(), windowDays: Int): Boolean {
        if (toShip <= 0 || clientDate == null) return false
        return clientDate.isBefore(today.plusDays(windowDays.toLong()))
    }

    fun daysLeft(until: LocalDate?, today: LocalDate = LocalDate.now()): Int? =
        until?.let { ChronoUnit.DAYS.between(today, it).toInt() }
}
