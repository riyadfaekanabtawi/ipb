package com.nevutech.trama.feature.dashboard

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Factory
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PendingActions
import androidx.compose.material.icons.filled.PrecisionManufacturing
import androidx.compose.material.icons.filled.Report
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.ReportEntity
import com.nevutech.trama.core.data.summary
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.AppSection
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.UrgencyPolicy
import com.nevutech.trama.designsystem.KpiTile
import com.nevutech.trama.designsystem.LoomBackdrop
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.ProgressRing
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.tint
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Admin landing page (port of ios DashboardView): live KPIs, plant capacity, booked revenue,
 * cutting pipeline and the lists that need attention today. Everything derives from the live [Graph].
 */
@Composable
fun DashboardScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val graph by rememberGraph()
    val user by app.session.user.collectAsState()
    val urgency by app.settings.urgencyWindowDays.collectAsState(initial = 7)
    val company by app.settings.companyName.collectAsState(initial = "")
    val online = rememberIsOnline()
    var monthKey by rememberSaveable { mutableStateOf(YearMonth.now().toString()) }
    val month = YearMonth.parse(monthKey)
    val setMonth: (YearMonth) -> Unit = { monthKey = it.toString() }
    val updatedAt = remember(graph) { LocalTime.now() }

    val s = remember(graph, month, urgency) { DashboardSnapshot(graph, month, urgency) }

    TramaScreen {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val wide = maxWidth >= 900.dp
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(Modifier.widthIn(max = 1400.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(22.dp)) {
                    DashboardHero(user?.firstName, company, online, updatedAt, s.urgent.size, s.unassignedGarments)
                    Kpis(s, urgency) { navigator.openSection(it) }

                    val capacity = @Composable { m: Modifier -> CapacityCard(s.capacity, month, setMonth, m) }
                    val pipeline = @Composable { m: Modifier -> PipelineCard(s.pipeline, m) { navigator.openSection(AppSection.Board) } }
                    TwoUp(wide, { capacity(it) }, { pipeline(it) }, secondWidth = 340)

                    RevenueYearCard(s.yearly, s.plantNames, month, setMonth)

                    TwoUp(
                        wide,
                        { UrgentList(s, graph, urgency, it, onAll = { navigator.openSection(AppSection.Shipments) }) { a -> navigator.openAssignment(a.id) } },
                        { PendingList(s, graph, it, onAll = { navigator.openSection(AppSection.Orders) }) { o -> navigator.openOrder(o.id) } },
                    )

                    ReportsFeed(graph.reports.take(8), graph, wide) { navigator.openAssignment(it.assignmentId) }
                }
            }
        }
    }
}

/** Side by side when wide, stacked otherwise (SwiftUI `ViewThatFits`). */
@Composable
private fun TwoUp(wide: Boolean, first: @Composable (Modifier) -> Unit, second: @Composable (Modifier) -> Unit, secondWidth: Int? = null) {
    if (wide) {
        Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.Top) {
            first(Modifier.weight(1f))
            second(if (secondWidth != null) Modifier.width(secondWidth.dp) else Modifier.weight(1f))
        }
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            first(Modifier.fillMaxWidth())
            second(Modifier.fillMaxWidth())
        }
    }
}

// Snapshot

/** Everything the dashboard shows, derived in one pass from the graph. */
class DashboardSnapshot(graph: Graph, month: YearMonth, urgencyWindow: Int, today: LocalDate = LocalDate.now()) {
    data class UrgentItem(val assignment: AssignmentEntity, val toShip: Int, val daysLeft: Int?)

    var revenue = 0.0; private set
    val assignmentCount = graph.assignments.size
    var inProduction = 0; private set
    var toShip = 0; private set
    val unassignedGarments: Long
    val urgent: List<UrgentItem>
    val pendingOrders: List<CutOrderEntity>
    val pipeline: List<Pair<CutStatus, Int>>
    val capacity: List<BarPoint>
    val plantNames: List<String> = graph.plants.map { it.name }
    val yearly: List<StackSeries>

    init {
        val urgentItems = mutableListOf<UrgentItem>()
        val statusCounts = HashMap<CutStatus, Int>()
        graph.assignments.forEach { a ->
            val m = graph.metrics(a)
            revenue += m.revenue
            toShip += m.toShip
            if (!m.isComplete) inProduction++
            statusCounts.merge(graph.cutStatus(a), 1, Int::plus)
            val clientDate = graph.clientDate(a)
            if (UrgencyPolicy.isUrgent(m.toShip, clientDate, today, urgencyWindow)) {
                urgentItems += UrgentItem(a, m.toShip, UrgencyPolicy.daysLeft(clientDate, today))
            }
        }
        urgent = urgentItems.sortedBy { it.daysLeft ?: Int.MAX_VALUE }
        pipeline = CutStatus.entries.map { it to (statusCounts[it] ?: 0) }

        val pending = graph.orders.filter { graph.remaining(it) > 0 }
        pendingOrders = pending.filter { it.clientDate != null }.sortedBy { it.clientDate } + pending.filter { it.clientDate == null }
        unassignedGarments = pending.sumOf { graph.remaining(it) }

        capacity = graph.plants.map { p -> BarPoint(p.name, graph.ledger(p).used(month), p.maxCapacity) }
        yearly = graph.plants.map { p ->
            val usage = graph.ledger(p).monthlyUsage(month.year)
            StackSeries(p.name, Tokens.accent(p.name), (1..12).map { usage[it] ?: 0.0 })
        }
    }
}

// Hero

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DashboardHero(name: String?, company: String, online: Boolean, updatedAt: LocalTime, urgentCount: Int, unassigned: Long) {
    val salute = when (LocalTime.now().hour) {
        in 5..11 -> "Buenos días"
        in 12..18 -> "Buenas tardes"
        else -> "Buenas noches"
    }
    val greeting = if (name.isNullOrBlank()) salute else "$salute, $name"
    val summary = listOf(
        if (urgentCount == 0) "Sin envíos urgentes" else "$urgentCount ${if (urgentCount == 1) "envío urgente" else "envíos urgentes"}",
        if (unassigned == 0L) "todo asignado" else "${Fmt.int(unassigned)} prendas por asignar",
    ).joinToString(" · ")
    val today = MonthLabel.fullDay(LocalDate.now())

    Box(
        Modifier.fillMaxWidth().height(230.dp)
            .shadow(24.dp, RoundedCornerShape(28.dp), ambientColor = Tokens.colors.brandDeep, spotColor = Tokens.colors.brandDeep)
            .clip(RoundedCornerShape(28.dp))
            .semantics(mergeDescendants = true) { contentDescription = "$greeting. $today. $summary" },
    ) {
        LoomBackdrop(Modifier.fillMaxSize())
        Column(Modifier.fillMaxSize().padding(28.dp)) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                HeroCapsule(if (online) "En línea" else "Sin conexión · modo local", if (online) Icons.Filled.Wifi else Icons.Filled.WifiOff)
                if (company.isNotBlank()) HeroCapsule(company, Icons.Filled.Apartment)
                HeroCapsule("Actualizado ${updatedAt.format(DateTimeFormatter.ofPattern("HH:mm"))}", Icons.Filled.Sync)
            }
            Spacer(Modifier.weight(1f))
            Text(greeting, color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.ExtraBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(today, color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.titleMedium)
            Text(summary, color = Color.White.copy(alpha = 0.75f), style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun HeroCapsule(text: String, icon: ImageVector) {
    Row(
        Modifier.clip(Tokens.chipShape).background(Color.White.copy(alpha = 0.16f)).padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, null, tint = Color.White, modifier = Modifier.size(14.dp))
        Text(text, color = Color.White, style = MaterialTheme.typography.labelMedium, maxLines = 1)
    }
}

// KPIs

@Composable
private fun Kpis(s: DashboardSnapshot, urgency: Int, open: (AppSection) -> Unit) {
    data class Kpi(val title: String, val value: String, val icon: ImageVector, val tint: Color, val footnote: String, val section: AppSection)
    val c = Tokens.colors
    val items = listOf(
        Kpi("Ingresos en producción", Fmt.money(s.revenue, compact = true), Icons.Filled.Payments, c.brand, "${Fmt.int(s.assignmentCount)} asignaciones", AppSection.Production),
        Kpi("Prendas por asignar", Fmt.int(s.unassignedGarments), Icons.Filled.ContentCut, c.thread, "${Fmt.int(s.pendingOrders.size)} cortes pendientes", AppSection.Orders),
        Kpi("En producción", Fmt.int(s.inProduction), Icons.Filled.PrecisionManufacturing, c.info, "Cortes sin terminar", AppSection.Production),
        Kpi("Envíos urgentes", Fmt.int(s.urgent.size), Icons.Filled.Warning, if (s.urgent.isEmpty()) c.success else c.danger, "Próximos $urgency días", AppSection.Shipments),
        Kpi("Por enviar", Fmt.int(s.toShip), Icons.Filled.Inventory2, c.success, "Prendas", AppSection.Shipments),
    )
    AdaptiveGrid(items.size, minWidth = 180.dp) { i, m ->
        val k = items[i]
        KpiTile(
            k.title, k.value, k.icon, k.tint, k.footnote,
            m.semantics(mergeDescendants = true) { contentDescription = "${k.title}: ${k.value}. ${k.footnote}" },
        ) { open(k.section) }
    }
}

// Charts

@Composable
private fun CapacityCard(points: List<BarPoint>, month: YearMonth, onMonth: (YearMonth) -> Unit, modifier: Modifier) {
    val used = points.sumOf { it.value }
    val max = points.sumOf { it.max }
    ChartCard(
        "Capacidad de plantas",
        if (max > 0) "${Fmt.money(used, compact = true)} de ${Fmt.money(max, compact = true)} · ${Fmt.percent(used / max)}" else "Usado vs. capacidad mensual",
        modifier,
        trailing = {},
    ) {
        MonthStepper(month, onMonth)
        if (points.isEmpty()) CardEmptyState("Sin plantas", Icons.Filled.Apartment, "Da de alta plantas para ver su capacidad.")
        else CapacityBarChart(points)
    }
}

@Composable
private fun PipelineCard(slices: List<Pair<CutStatus, Int>>, modifier: Modifier, onOpen: () -> Unit) {
    val total = slices.sumOf { it.second }
    ChartCard("Mesa de corte", "Asignaciones por estado", modifier, trailing = {
        TextButton(onOpen) {
            Text("Tablero", style = MaterialTheme.typography.labelLarge)
            Icon(Icons.AutoMirrored.Filled.OpenInNew, null, Modifier.padding(start = 4.dp).size(16.dp))
        }
    }) {
        if (total == 0) {
            CardEmptyState("Sin asignaciones", Icons.Filled.ContentCut, "Asigna cortes a una planta para verlos aquí.")
        } else {
            val tinted = slices.map { (status, count) -> DonutSlice(status.title, count, status.tint()) }
            Column(
                Modifier.clickable(role = Role.Button, onClickLabel = "Abre el tablero de corte", onClick = onOpen)
                    .semantics(mergeDescendants = true) {
                        contentDescription = "$total cortes. " + tinted.joinToString(", ") { "${it.label}: ${it.value}" }
                    },
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                DonutChart(tinted, Fmt.int(total), "cortes")
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    tinted.forEach { LegendRow(it.color, it.label, Fmt.int(it.value)) }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun RevenueYearCard(series: List<StackSeries>, plantNames: List<String>, month: YearMonth, onMonth: (YearMonth) -> Unit) {
    val total = series.sumOf { it.values.sum() }
    ChartCard(
        "Ingresos agendados ${month.year}",
        "${Fmt.money(total, compact = true)} por mes de producción, por planta",
    ) {
        if (plantNames.isNotEmpty()) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                plantNames.take(4).forEach { LegendChip(Tokens.accent(it), it) }
            }
        }
        if (total == 0.0) {
            CardEmptyState("Sin ingresos agendados en ${month.year}", Icons.Filled.BarChart, "Las asignaciones a planta aparecerán aquí por mes.")
        } else {
            val labels = (1..12).map { MonthLabel.short(YearMonth.of(month.year, it)).capitalizedFirst() }
            StackedBarChart(
                series, labels, selected = month.monthValue - 1,
                onSelect = { onMonth(YearMonth.of(month.year, it + 1)) },
                modifier = Modifier.semantics { contentDescription = "Ingresos agendados por mes en ${month.year}: ${Fmt.money(total)}" },
            )
        }
    }
}

// Lists

@Composable
private fun UrgentList(s: DashboardSnapshot, graph: Graph, urgency: Int, modifier: Modifier, onAll: () -> Unit, onOpen: (AssignmentEntity) -> Unit) {
    ChartCard("Envíos urgentes", "Por fecha de cliente", modifier, trailing = { TextButton(onAll) { Text("Ver todos") } }) {
        if (s.urgent.isEmpty()) {
            CardEmptyState("Sin envíos urgentes", Icons.Filled.Verified, "Todo va a tiempo en los próximos $urgency días.")
        } else {
            Column {
                s.urgent.take(5).forEachIndexed { i, row ->
                    if (i > 0) HorizontalDivider(Modifier.padding(start = 56.dp), color = Tokens.colors.stroke)
                    UrgentRow(row, graph) { onOpen(row.assignment) }
                }
            }
        }
    }
}

@Composable
private fun UrgentRow(row: DashboardSnapshot.UrgentItem, graph: Graph, onClick: () -> Unit) {
    val days = row.daysLeft
    val c = Tokens.colors
    val tint = when {
        days == null -> c.secondary
        days < 0 -> c.danger
        days <= 2 -> c.warning
        else -> c.info
    }
    val order = graph.orderOf(row.assignment)
    val title = "${graph.title(row.assignment)} · ${graph.clientName(order)}"
    val detail = "${graph.plantName(row.assignment)} · ${Fmt.int(row.toShip)} por enviar"
    ListRow(
        icon = if ((days ?: 0) < 0) Icons.Filled.Report else Icons.Filled.PendingActions, tint = tint,
        title = title, detail = detail, onClick = onClick,
        a11y = "$title. $detail. ${Fmt.relativeDays(days)}",
    ) { Pill(Fmt.relativeDays(days), tint) }
}

@Composable
private fun PendingList(s: DashboardSnapshot, graph: Graph, modifier: Modifier, onAll: () -> Unit, onOpen: (CutOrderEntity) -> Unit) {
    ChartCard("Cortes por asignar", "Más próximos a entregar", modifier, trailing = { TextButton(onAll) { Text("Ver todos") } }) {
        if (s.pendingOrders.isEmpty()) {
            CardEmptyState("Todo asignado", Icons.Filled.Inbox, "No hay prendas pendientes de asignar a planta.")
        } else {
            Column {
                s.pendingOrders.take(5).forEachIndexed { i, order ->
                    if (i > 0) HorizontalDivider(Modifier.padding(start = 56.dp), color = Tokens.colors.stroke)
                    PendingRow(order, graph) { onOpen(order) }
                }
            }
        }
    }
}

@Composable
private fun PendingRow(order: CutOrderEntity, graph: Graph, onClick: () -> Unit) {
    val remaining = graph.remaining(order)
    val progress = if (order.quantity > 0) graph.assignedQuantity(order).toDouble() / order.quantity else 0.0
    val tint = graph.state(order).tint()
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
            .clickable(role = Role.Button, onClick = onClick)
            .semantics(mergeDescendants = true) {
                contentDescription = "Corte ${order.code}, ${graph.clientName(order)}, ${Fmt.int(remaining)} prendas por asignar"
            }
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
            ProgressRing(progress, Modifier.size(40.dp), tint, stroke = 5.dp)
            Icon(Icons.Filled.ContentCut, null, tint = tint, modifier = Modifier.size(16.dp))
        }
        Column(Modifier.weight(1f)) {
            Text("${order.code} · ${order.list.ifBlank { "—" }}", style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text("${graph.clientName(order)} · ${graph.styleName(order)}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(Fmt.int(remaining), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Text("Cliente ${Fmt.shortDate(order.clientDate?.toLocalDate())}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Tokens.colors.secondary.copy(alpha = 0.5f))
    }
}

@Composable
private fun ListRow(icon: ImageVector, tint: Color, title: String, detail: String, onClick: () -> Unit, a11y: String, trailing: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
            .clickable(role = Role.Button, onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = a11y }
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(detail, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        trailing()
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Tokens.colors.secondary.copy(alpha = 0.5f))
    }
}

@Composable
private fun ReportsFeed(reports: List<ReportEntity>, graph: Graph, wide: Boolean, onOpen: (ReportEntity) -> Unit) {
    ChartCard("Actividad reciente", "Últimos reportes de producción") {
        if (reports.isEmpty()) {
            CardEmptyState("Sin reportes todavía", Icons.Filled.Description, "Los reportes de planta, corte y envío aparecerán aquí.")
        } else {
            AdaptiveGrid(reports.size, minWidth = if (wide) 380.dp else 600.dp, spacing = 8.dp) { i, m ->
                ReportFeedRow(reports[i], graph, m) { onOpen(reports[i]) }
            }
        }
    }
}

@Composable
private fun ReportFeedRow(report: ReportEntity, graph: Graph, modifier: Modifier, onClick: () -> Unit) {
    val kind = ReportKind.fromRaw(report.kind)
    val tint = kind.tint()
    val assignment = graph.assignment(report.assignmentId)
    val heading = "${assignment?.let(graph::title) ?: "Corte"} · ${assignment?.let(graph::plantName).orEmpty()}"
    val footer = "${report.authorName ?: "Sin autor"} · ${relativeTime(report.createdAt)}"
    Row(
        modifier.clip(RoundedCornerShape(Tokens.smallRadius)).background(Tokens.colors.surfaceRaised)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = "${kind.shortTitle}. $heading. ${report.summary()}. $footer" }
            .padding(10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(11.dp)).background(tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
            Icon(kind.icon, null, tint = tint, modifier = Modifier.size(18.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(kind.shortTitle, style = MaterialTheme.typography.labelMedium, color = tint)
                Text(heading, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text(report.summary(), style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(footer, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

private val ReportKind.icon: ImageVector
    get() = when (this) {
        ReportKind.Plant -> Icons.Filled.Factory
        ReportKind.Cut -> Icons.Filled.ContentCut
        ReportKind.Shipment -> Icons.Filled.LocalShipping
    }

/** Spanish relative time, like iOS `.relative(presentation: .named)` in es_MX. */
fun relativeTime(epochMillis: Long, now: Instant = Instant.now()): String {
    val then = Instant.ofEpochMilli(epochMillis)
    val minutes = ChronoUnit.MINUTES.between(then, now)
    if (minutes < 0) return "ahora"
    fun plural(n: Long, one: String, many: String) = "hace $n ${if (n == 1L) one else many}"
    return when {
        minutes < 1 -> "ahora"
        minutes < 60 -> plural(minutes, "minuto", "minutos")
        minutes < 24 * 60 -> plural(minutes / 60, "hora", "horas")
        else -> {
            val zone = ZoneId.systemDefault()
            val days = ChronoUnit.DAYS.between(then.atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate())
            when {
                days <= 1 -> "ayer"
                days < 7 -> "hace $days días"
                days < 30 -> plural(days / 7, "semana", "semanas")
                days < 365 -> plural(days / 30, "mes", "meses")
                else -> plural(days / 365, "año", "años")
            }
        }
    }
}

/** Live network reachability. Trama never needs it; it is only shown so users know they are offline-safe. */
@Composable
fun rememberIsOnline(): Boolean {
    val context = LocalContext.current
    val manager = remember { context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager }
    var online by remember {
        mutableStateOf(manager?.getNetworkCapabilities(manager.activeNetwork)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true)
    }
    DisposableEffect(manager) {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { online = true }
            override fun onLost(network: Network) {
                online = manager?.activeNetwork?.let { it != network && manager.getNetworkCapabilities(it) != null } == true
            }
        }
        runCatching { manager?.registerDefaultNetworkCallback(callback) }
        onDispose { runCatching { manager?.unregisterNetworkCallback(callback) } }
    }
    return online
}
