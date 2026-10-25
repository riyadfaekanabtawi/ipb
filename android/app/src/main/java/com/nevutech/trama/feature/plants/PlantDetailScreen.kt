package com.nevutech.trama.feature.plants

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.CapacityLedger
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.CapacityBar
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.capacityTint
import com.nevutech.trama.designsystem.tint
import com.nevutech.trama.feature.clients.CatalogRowCard
import com.nevutech.trama.feature.clients.ConfirmDeleteDialog
import com.nevutech.trama.feature.clients.DetailHero
import com.nevutech.trama.feature.clients.DetailScaffold
import com.nevutech.trama.feature.clients.HeroStat
import com.nevutech.trama.feature.clients.MenuItem
import com.nevutech.trama.feature.clients.OverflowMenu
import com.nevutech.trama.feature.clients.PickerField
import com.nevutech.trama.feature.clients.RowFigure
import com.nevutech.trama.feature.clients.SectionTitle
import com.nevutech.trama.feature.clients.icon
import java.time.LocalDate
import java.time.Month
import java.time.YearMonth
import java.time.format.TextStyle as JavaTextStyle

@Composable
fun PlantDetailScreen(id: String) {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    var year by rememberSaveable { mutableIntStateOf(LocalDate.now().year) }
    var editing by remember { mutableStateOf(false) }
    var confirmingDelete by remember { mutableStateOf(false) }
    var statusFilter by rememberSaveable { mutableStateOf<CutStatus?>(null) }

    val plant = graph.plant(id)
    TramaScreen {
        if (plant == null) {
            DetailScaffold("Planta") { EmptyState("Planta no encontrada", "Es posible que se haya eliminado.", Icons.Filled.SearchOff) }
            return@TramaScreen
        }
        val ledger = graph.ledger(plant)
        val all = graph.assignmentsOf(plant)
        val assignments = all.sortedByDescending { it.createdAt }.filter { statusFilter == null || graph.cutStatus(it) == statusFilter }
        val month = YearMonth.now()
        val used = ledger.used(month)

        DetailScaffold(plant.name, actions = {
            IconButton({ editing = true }) { Icon(Icons.Filled.Edit, "Editar") }
            OverflowMenu { close -> MenuItem("Eliminar planta", Icons.Filled.Delete, destructive = true) { close(); confirmingDelete = true } }
        }) {
            Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                DetailHero(plant.name, "Capacidad de ${Fmt.money(plant.maxCapacity)} por mes", leading = { Avatar(plant.name, size = 72.dp, icon = Icons.Filled.Apartment) }) {
                    HeroStat(Fmt.money(used, compact = true), "Usado este mes")
                    HeroStat(Fmt.money(maxOf(0.0, ledger.available(month)), compact = true), "Disponible")
                    HeroStat(Fmt.int(graph.openAssignmentCount(plant)), "Activas")
                }
                TramaCard(Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Ocupación de ${monthName(LocalDate.now()).lowercase(Fmt.locale)}", style = MaterialTheme.typography.labelLarge)
                            CapacityBar(used, plant.maxCapacity, height = 14.dp)
                        }
                        val ratio = ledger.utilization(month)
                        Text(Fmt.percent(ratio), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = capacityTint(ratio.toFloat()))
                        VerticalDivider(Modifier.height(44.dp), color = Tokens.colors.stroke)
                        ManagersStack(graph.managersOf(plant).sortedBy { it.firstName })
                    }
                }
            }

            TramaCard(Modifier.fillMaxWidth()) {
                PlantCapacityChart(ledger, year, { year = it }, availableYears(ledger))
            }

            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SectionTitle("Asignaciones", "${Fmt.int(all.size)} en total") {
                    PickerField(
                        "Estado", listOf<CutStatus?>(null) + CutStatus.entries, statusFilter, { it?.title ?: "Todas" }, { statusFilter = it },
                        Modifier.widthIn(max = 260.dp),
                    )
                }
                if (assignments.isEmpty()) {
                    EmptyState(
                        if (statusFilter == null) "Sin asignaciones" else "Nada en este estado",
                        "Los cortes asignados a esta planta aparecerán aquí.", Icons.Filled.ContentCut,
                    )
                } else {
                    assignments.forEach { a -> PlantAssignmentRow(graph, a) { navigator.openAssignment(a.id) } }
                }
            }
        }
    }

    if (editing && plant != null) PlantEditorSheet(plant, graph) { editing = false }
    if (confirmingDelete && plant != null) {
        ConfirmDeleteDialog(
            "¿Eliminar ${plant.name}?", "Solo se pueden eliminar plantas sin cortes asignados.",
            onConfirm = { actions.run(success = "Planta «${plant.name}» eliminada", onDone = { navigator.back() }) { app.production().deletePlant(plant) } },
            onDismiss = { confirmingDelete = false },
        )
    }
}

private fun availableYears(ledger: CapacityLedger): IntRange {
    val current = LocalDate.now().year
    val years = ledger.bookings.map { it.date.year }
    return minOf(years.minOrNull() ?: current, current)..maxOf(years.maxOrNull() ?: current, current + 1)
}

/** 12-month bar chart of booked capacity against the plant's monthly maximum. Tap a bar for its values. */
@Composable
fun PlantCapacityChart(ledger: CapacityLedger, year: Int, onYear: (Int) -> Unit, years: IntRange) {
    val usage = ledger.monthlyUsage(year)
    val data = (1..12).map { usage[it] ?: 0.0 }
    val total = data.sum()
    var selected by remember(year) { mutableStateOf<Int?>(null) }
    val top = maxOf(ledger.maxCapacity * 1.15, (data.maxOrNull() ?: 0.0) * 1.1, 1.0)
    val animated = data.map { v -> animateFloatAsState((v / top).toFloat(), spring(stiffness = 300f), label = "bar").value }
    val tints = data.map { capacityTint(if (ledger.maxCapacity > 0) (it / ledger.maxCapacity).toFloat() else 0f) }
    val measurer = rememberTextMeasurer()
    val c = Tokens.colors
    val axisStyle = TextStyle(fontSize = 11.sp, color = c.secondary)
    val maxStyle = TextStyle(fontSize = 11.sp, color = c.danger, fontWeight = FontWeight.SemiBold)
    val monthLabels = Month.entries.map { it.getDisplayName(JavaTextStyle.SHORT_STANDALONE, Fmt.locale).trimEnd('.') }

    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Capacidad por mes", style = MaterialTheme.typography.titleLarge)
                Text("Asignado en $year: ${Fmt.money(total, compact = true)}", style = MaterialTheme.typography.bodyMedium, color = c.secondary)
            }
            YearStepper(year, years, onYear)
        }

        val pick = selected
        Box(Modifier.fillMaxWidth().height(36.dp)) {
            if (pick != null) {
                val value = data[pick]
                Row(
                    Modifier.clip(RoundedCornerShape(10.dp)).background(c.brand.copy(alpha = 0.08f)).padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Text(Fmt.monthYear(LocalDate.of(year, pick + 1, 1)), style = MaterialTheme.typography.labelMedium)
                    Text("Usado ${Fmt.money(value)}", style = MaterialTheme.typography.bodySmall)
                    Text("Disponible ${Fmt.money(maxOf(0.0, ledger.maxCapacity - value))}", style = MaterialTheme.typography.bodySmall, color = c.secondary)
                }
            } else {
                Text("Toca un mes para ver su detalle.", style = MaterialTheme.typography.bodySmall, color = c.secondary, modifier = Modifier.align(Alignment.CenterStart))
            }
        }

        Canvas(
            Modifier.fillMaxWidth().height(280.dp)
                .semantics { contentDescription = "Gráfica de capacidad usada por mes en $year" }
                .pointerInput(year) {
                    detectTapGestures { tap ->
                        val left = 64.dp.toPx()
                        val slot = (size.width - left) / 12f
                        val index = ((tap.x - left) / slot).toInt()
                        selected = if (tap.x < left || index !in 0..11 || selected == index) null else index
                    }
                },
        ) {
            val left = 64.dp.toPx()
            val bottom = 22.dp.toPx()
            val chartH = size.height - bottom
            val slot = (size.width - left) / 12f
            fun y(fraction: Float) = chartH * (1 - fraction)

            // Grid lines with compact money labels.
            for (i in 0..4) {
                val f = i / 4f
                drawLine(c.ink.copy(alpha = 0.06f), Offset(left, y(f)), Offset(size.width, y(f)), 1f)
                val label = measurer.measure(Fmt.money(top * f, compact = true), axisStyle)
                drawText(label, topLeft = Offset(left - label.size.width - 8.dp.toPx(), y(f) - label.size.height / 2f))
            }
            if (selected != null) {
                drawRoundRect(c.brand.copy(alpha = 0.12f), Offset(left + slot * selected!!, 0f), Size(slot, chartH), CornerRadius(8.dp.toPx()))
            }
            animated.forEachIndexed { i, fraction ->
                val barW = slot * 0.56f
                val x = left + slot * i + (slot - barW) / 2
                val h = chartH * fraction
                val alpha = if (selected == null || selected == i) 1f else 0.45f
                if (h > 0f) {
                    drawRoundRect(
                        Brush.verticalGradient(listOf(tints[i].copy(alpha = alpha), tints[i].copy(alpha = 0.7f * alpha)), startY = chartH - h, endY = chartH),
                        Offset(x, chartH - h), Size(barW, h), CornerRadius(6.dp.toPx()),
                    )
                }
                val label = measurer.measure(monthLabels[i], axisStyle)
                drawText(label, topLeft = Offset(left + slot * i + (slot - label.size.width) / 2, chartH + 6.dp.toPx()))
            }
            if (ledger.maxCapacity > 0) {
                val my = y((ledger.maxCapacity / top).toFloat())
                drawLine(c.danger, Offset(left, my), Offset(size.width, my), 1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(18f, 12f)))
                val label = measurer.measure("Máx. ${Fmt.money(ledger.maxCapacity, compact = true)}", maxStyle)
                drawText(label, topLeft = Offset(left + 4.dp.toPx(), my - label.size.height - 2.dp.toPx()))
            }
        }
    }
}

/** Compact ‹ 2026 › year switcher. */
@Composable
fun YearStepper(year: Int, range: IntRange, onChange: (Int) -> Unit) {
    Row(
        Modifier.clip(Tokens.chipShape).background(Tokens.colors.brand.copy(alpha = 0.08f)).padding(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton({ onChange(year - 1) }, enabled = year > range.first, modifier = Modifier.size(36.dp)) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Año anterior")
        }
        Text("$year", style = MaterialTheme.typography.titleMedium, modifier = Modifier.widthIn(min = 52.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        IconButton({ onChange(year + 1) }, enabled = year < range.last, modifier = Modifier.size(36.dp)) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Año siguiente")
        }
    }
}

@Composable
private fun PlantAssignmentRow(graph: Graph, assignment: AssignmentEntity, onClick: () -> Unit) {
    val status = graph.cutStatus(assignment)
    val metrics = graph.metrics(assignment)
    androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxWidth()) {
    val width = maxWidth
    CatalogRowCard(onClick) {
        Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(status.tint().copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
            Icon(status.icon, null, tint = status.tint(), modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(graph.title(assignment), style = MaterialTheme.typography.titleMedium)
            Text(graph.clientName(graph.orderOf(assignment)), style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(22.dp), verticalAlignment = Alignment.CenterVertically) {
            if (width > 700.dp) {
                RowFigure(Fmt.int(assignment.quantity), "prendas")
                RowFigure(Fmt.shortDate(assignment.scheduledDate?.toLocalDate()), "fecha")
            }
            if (width > 480.dp) RowFigure(Fmt.int(metrics.toShip), "por enviar")
            Pill(status.title, status.tint())
        }
    }
    }
}
