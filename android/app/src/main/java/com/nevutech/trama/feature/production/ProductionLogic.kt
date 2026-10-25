package com.nevutech.trama.feature.production

import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.AssignmentMetrics
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.UrgencyPolicy
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

// Pure, Compose-free logic behind the production screens, kept here so it is unit tested
// (ProductionFeatureTest) and shared by several screens.

/** One flattened, sortable row per assignment (port of iOS ProductionRow). */
data class ProductionRow(
    val id: String,
    val orderId: String?,
    val code: String,
    val list: String,
    val client: String,
    val clientId: String?,
    val style: String,
    val garment: String,
    val plant: String,
    val plantId: String?,
    val status: CutStatus,
    val internalDate: LocalDate?,
    val clientDate: LocalDate?,
    val metrics: AssignmentMetrics,
) {
    val quantity get() = metrics.quantity
    val realCut get() = metrics.realCut
    val produced get() = metrics.produced
    val ironing get() = metrics.ironing
    val packing get() = metrics.packing
    val warehouse get() = metrics.warehouse
    val shipped get() = metrics.shipped
    val toShip get() = metrics.toShip
    val revenue get() = metrics.revenue

    companion object {
        fun of(graph: Graph, a: AssignmentEntity): ProductionRow {
            val order = graph.orderOf(a)
            return ProductionRow(
                id = a.id,
                orderId = order?.id,
                code = order?.code ?: "—",
                list = order?.list.orEmpty(),
                client = order?.let { graph.clientName(it) }.orEmpty(),
                clientId = order?.clientId,
                style = order?.let { graph.styleName(it) }.orEmpty(),
                garment = order?.garment.orEmpty(),
                plant = graph.plantName(a),
                plantId = a.plantId,
                status = graph.cutStatus(a),
                internalDate = order?.internalDate?.toLocalDate(),
                clientDate = order?.clientDate?.toLocalDate(),
                metrics = graph.metrics(a),
            )
        }
    }
}

/** Filters of the production list; null fields mean "any". */
data class ProductionFilter(
    val query: String = "",
    val plantId: String? = null,
    val clientId: String? = null,
    val status: CutStatus? = null,
    val onlyPending: Boolean = false,
    val from: LocalDate? = null,
    val to: LocalDate? = null,
) {
    val isActive: Boolean
        get() = plantId != null || clientId != null || status != null || onlyPending || from != null || query.isNotBlank()

    fun matches(row: ProductionRow, searchText: String): Boolean {
        val q = query.trim().lowercase()
        if (plantId != null && row.plantId != plantId) return false
        if (clientId != null && row.clientId != clientId) return false
        if (status != null && row.status != status) return false
        if (q.isNotEmpty() && !searchText.contains(q)) return false
        if (onlyPending && row.toShip <= 0) return false
        if (from != null && to != null) {
            val d = row.clientDate ?: return false
            if (d.isBefore(from) || d.isAfter(to)) return false
        }
        return true
    }
}

enum class ProductionSort(val title: String) {
    ClientDate("Fecha de entrega"),
    Code("Corte"),
    Plant("Planta"),
    Status("Estado"),
    Quantity("Cantidad"),
    ToShip("Por enviar"),
    Revenue("Ingreso");

    fun comparator(descending: Boolean): Comparator<ProductionRow> {
        val base: Comparator<ProductionRow> = when (this) {
            // Missing client dates sort last (iOS uses .distantFuture).
            ClientDate -> compareBy { it.clientDate ?: LocalDate.MAX }
            Code -> compareBy(String.CASE_INSENSITIVE_ORDER) { it.code }
            Plant -> compareBy(String.CASE_INSENSITIVE_ORDER) { it.plant }
            Status -> compareBy { it.status.title }
            Quantity -> compareBy { it.quantity }
            ToShip -> compareBy { it.toShip }
            Revenue -> compareBy { it.revenue }
        }
        return if (descending) base.reversed() else base
    }
}

fun productionRows(graph: Graph, assignments: List<AssignmentEntity>, filter: ProductionFilter, sort: ProductionSort, descending: Boolean) =
    assignments.map { it to ProductionRow.of(graph, it) }
        .filter { (a, row) -> filter.matches(row, graph.searchText(a)) }
        .map { it.second }
        .sortedWith(sort.comparator(descending))

/** CSV export with the same columns as iOS ProductionCSV. */
object ProductionCsv {
    const val FILE_NAME = "Trama-produccion.csv"
    const val BOM = "﻿"

    val header = listOf(
        "Corte", "Lista", "Cliente", "Estilo", "Prenda", "Planta", "Estado", "Cantidad", "Cortadas", "Producidas",
        "Plancha", "Empaque", "Bodega", "Enviadas", "Por enviar", "Ingreso", "Fecha interna", "Fecha cliente",
    )

    fun escape(s: String): String =
        if (s.any { it == ',' || it == '"' || it == '\n' }) "\"" + s.replace("\"", "\"\"") + "\"" else s

    fun build(rows: List<ProductionRow>): String {
        val lines = rows.map { r ->
            listOf(
                r.code, r.list, r.client, r.style, r.garment, r.plant, r.status.title, "${r.quantity}", "${r.realCut}", "${r.produced}",
                "${r.ironing}", "${r.packing}", "${r.warehouse}", "${r.shipped}", "${r.toShip}", String.format(Locale.US, "%.2f", r.revenue),
                r.internalDate?.toString().orEmpty(), r.clientDate?.toString().orEmpty(),
            ).joinToString(",", transform = ::escape)
        }
        return (listOf(header.joinToString(",")) + lines).joinToString("\n")
    }

    /** UTF-8 bytes with BOM so Excel opens accents correctly. */
    fun bytes(rows: List<ProductionRow>): ByteArray = (BOM + build(rows)).toByteArray(Charsets.UTF_8)
}

/** Month grid math for the plant calendar. Weeks start on Monday (es-MX). */
object CalendarMath {
    /** Leading nulls up to the month's first weekday, then every day of the month. */
    fun gridDays(month: YearMonth, firstDay: DayOfWeek = DayOfWeek.MONDAY): List<LocalDate?> {
        val first = month.atDay(1)
        val leading = (first.dayOfWeek.value - firstDay.value + 7) % 7
        return List(leading) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
    }

    fun weekdaySymbols(firstDay: DayOfWeek = DayOfWeek.MONDAY, locale: Locale = Fmt.locale): List<String> =
        (0 until 7).map { firstDay.plus(it.toLong()).getDisplayName(TextStyle.SHORT, locale).trimEnd('.') }
}

enum class OrderFilter(val title: String) {
    Pending("Por asignar"), All("Todos"), Assigned("Asignados");

    fun matches(graph: Graph, order: CutOrderEntity): Boolean = when (this) {
        Pending -> graph.remaining(order) > 0
        All -> true
        Assigned -> graph.remaining(order) == 0L
    }
}

/** Orders sorted like iOS: client date (missing last), then code. */
fun sortedOrders(orders: List<CutOrderEntity>) =
    orders.sortedWith(compareBy<CutOrderEntity> { it.clientDate ?: Long.MAX_VALUE }.thenBy { it.code })

/** Default plant for an assignment: the one with most room that month that fits the value, else the first. */
fun bestFitPlant(graph: Graph, plants: List<PlantEntity>, date: LocalDate, value: Double): PlantEntity? {
    val month = YearMonth.from(date)
    return plants.filter { graph.ledger(it).available(month) >= value }
        .maxByOrNull { graph.ledger(it).available(month) } ?: plants.firstOrNull()
}

/** Urgent assignments split into overdue and upcoming, sorted by client date. */
data class UrgentGroups(val overdue: List<AssignmentEntity>, val upcoming: List<AssignmentEntity>) {
    val all get() = overdue + upcoming

    companion object {
        fun of(graph: Graph, assignments: List<AssignmentEntity>, windowDays: Int, today: LocalDate = LocalDate.now()): UrgentGroups {
            val urgent = assignments.filter { graph.isUrgent(it, windowDays, today) }
                .sortedBy { graph.clientDate(it) ?: LocalDate.MAX }
            val (overdue, upcoming) = urgent.partition { (UrgencyPolicy.daysLeft(graph.clientDate(it), today) ?: 0) < 0 }
            return UrgentGroups(overdue, upcoming)
        }
    }
}

/** Calendar event: an assignment's production start or an order's client delivery. */
data class CalendarEvent(
    val id: String,
    val kind: Kind,
    val date: LocalDate,
    val title: String,
    val subtitle: String,
    /** Assignment id for production, order id for delivery. */
    val targetId: String,
    val plantName: String?,
) {
    enum class Kind { Production, Delivery }

    companion object {
        fun forMonth(graph: Graph, month: YearMonth, plantId: String?): List<CalendarEvent> {
            val production = graph.assignments.mapNotNull { a ->
                val date = a.scheduledDate?.toLocalDate() ?: return@mapNotNull null
                if (plantId != null && a.plantId != plantId) return@mapNotNull null
                val plant = graph.plantName(a)
                CalendarEvent("p-${a.id}", Kind.Production, date, graph.title(a), "$plant · ${Fmt.int(a.quantity)} prendas", a.id, plant)
            }
            val deliveries = graph.orders.mapNotNull { o ->
                val date = o.clientDate?.toLocalDate() ?: return@mapNotNull null
                if (plantId != null && graph.assignmentsOf(o).none { it.plantId == plantId }) return@mapNotNull null
                CalendarEvent("d-${o.id}", Kind.Delivery, date, o.code, "Entrega a ${graph.clientName(o)}", o.id, null)
            }
            return (production + deliveries).filter { YearMonth.from(it.date) == month }
        }
    }
}
