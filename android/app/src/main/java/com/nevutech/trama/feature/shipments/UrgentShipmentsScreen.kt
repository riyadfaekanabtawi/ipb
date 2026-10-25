package com.nevutech.trama.feature.shipments

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.UrgencyPolicy
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.KpiTile
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.feature.production.Meter
import com.nevutech.trama.feature.production.PlantPill
import com.nevutech.trama.feature.production.ReportEditorRequest
import com.nevutech.trama.feature.production.ReportEditorSheet
import com.nevutech.trama.feature.production.ScreenHeader
import com.nevutech.trama.feature.production.StatusDot
import com.nevutech.trama.feature.production.UrgentGroups
import com.nevutech.trama.feature.production.isWideLayout
import com.nevutech.trama.feature.production.rememberRole
import kotlinx.coroutines.launch
import kotlin.math.abs

/** "Envíos urgentes": cuts with garments still to ship whose client date is close or past. */
@Composable
fun UrgentShipmentsScreen() {
    val graph by rememberGraph()
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val user by app.session.user.collectAsState()
    val window by app.settings.urgencyWindowDays.collectAsState(initial = 7)
    val canShip = rememberRole().canEdit(ReportKind.Shipment)
    val wide = isWideLayout()
    var shipping by remember { mutableStateOf<String?>(null) }

    val groups = UrgentGroups.of(graph, graph.visibleAssignments(user), window)
    val garments = groups.all.sumOf { graph.metrics(it).toShip }

    TramaScreen {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            ScreenHeader(stringResource(R.string.section_shipments), showTitle = wide) { WindowMenu(window) }
            Column(Modifier.padding(horizontal = if (wide) 24.dp else 16.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
                val tiles: List<@Composable (Modifier) -> Unit> = listOf(
                    { KpiTile(stringResource(R.string.section_shipments), Fmt.int(groups.all.size), Icons.Filled.Warning, Tokens.colors.warning, modifier = it) },
                    { KpiTile(stringResource(R.string.shipments_overdue), Fmt.int(groups.overdue.size), Icons.Filled.Timer, Tokens.colors.danger, modifier = it) },
                    { KpiTile(stringResource(R.string.shipments_garments_to_ship), Fmt.int(garments), Icons.Filled.Inventory2, Tokens.colors.brand, modifier = it) },
                )
                if (wide) Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) { tiles.forEach { it(Modifier.weight(1f)) } }
                else Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) { tiles.forEach { it(Modifier.width(200.dp)) } }

                if (groups.all.isEmpty()) {
                    EmptyState(
                        stringResource(R.string.shipments_empty_title), pluralStringResource(R.plurals.shipments_empty_message, window, window), Icons.Filled.Verified,
                        Modifier.padding(top = 40.dp),
                    )
                }
                if (groups.overdue.isNotEmpty()) Group(stringResource(R.string.shipments_overdue), Tokens.colors.danger, groups.overdue, graph, canShip, navigator::openAssignment) { shipping = it }
                if (groups.upcoming.isNotEmpty()) Group(pluralStringResource(R.plurals.shipments_next_days, window, window), Tokens.colors.warning, groups.upcoming, graph, canShip, navigator::openAssignment) { shipping = it }
            }
        }
    }

    shipping?.let { id -> androidx.compose.runtime.key(id) { ReportEditorSheet(ReportEditorRequest.New(id, ReportKind.Shipment)) { shipping = null } } }
}

@Composable
private fun WindowMenu(window: Int) {
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    var open by remember { mutableStateOf(false) }
    val set: (Int) -> Unit = { days -> scope.launch { app.settings.setUrgencyWindowDays(days) } }
    val windowDescription = pluralStringResource(R.plurals.shipments_window_description, window, window)
    Box {
        Surface(
            onClick = { open = true }, shape = Tokens.chipShape, color = Tokens.colors.surface, border = BorderStroke(1.dp, Tokens.colors.stroke),
            modifier = Modifier.semantics { contentDescription = windowDescription },
        ) {
            Row(Modifier.padding(horizontal = 14.dp, vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.Timer, null, tint = Tokens.colors.brand, modifier = Modifier.size(18.dp))
                Text(pluralStringResource(R.plurals.shipments_window, window, window), style = MaterialTheme.typography.labelLarge)
            }
        }
        DropdownMenu(open, { open = false }) {
            Row(Modifier.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton({ set(window - 1) }, enabled = window > 1) { Icon(Icons.Filled.Remove, stringResource(R.string.shipments_fewer_days)) }
                Text(pluralStringResource(R.plurals.shipments_days_count, window, window), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(horizontal = 8.dp))
                IconButton({ set(window + 1) }, enabled = window < 30) { Icon(Icons.Filled.Add, stringResource(R.string.shipments_more_days)) }
            }
            HorizontalDivider()
            listOf(3, 7, 14, 30).forEach { days ->
                DropdownMenuItem(
                    text = { Text(pluralStringResource(R.plurals.shipments_days_count, days, days)) }, onClick = { set(days); open = false },
                    trailingIcon = if (days == window) ({ Icon(Icons.Filled.Check, null, tint = Tokens.colors.brand) }) else null,
                )
            }
        }
    }
}

@Composable
private fun Group(
    title: String, tint: Color, items: List<AssignmentEntity>, graph: Graph, canShip: Boolean,
    onOpen: (String) -> Unit, onShip: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StatusDot(tint)
            Text(title, style = MaterialTheme.typography.titleLarge)
            Text("${items.size}", style = MaterialTheme.typography.titleLarge, color = Tokens.colors.secondary, fontWeight = FontWeight.Normal)
        }
        BoxWithConstraints {
            val columns = maxOf(1, (maxWidth / 380.dp).toInt())
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                items.chunked(columns).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        row.forEach { a -> ShipmentCard(graph, a, canShip, Modifier.weight(1f), { onOpen(a.id) }) { onShip(a.id) } }
                        repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ShipmentCard(graph: Graph, a: AssignmentEntity, canShip: Boolean, modifier: Modifier, onOpen: () -> Unit, onShip: () -> Unit) {
    val c = Tokens.colors
    val metrics = graph.metrics(a)
    val days = UrgencyPolicy.daysLeft(graph.clientDate(a))
    val late = (days ?: 0) < 0
    val tint = if (late) c.danger else c.warning
    Surface(onClick = onOpen, modifier = modifier, shape = Tokens.cardShape, color = c.surface, border = BorderStroke(1.dp, c.stroke)) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Column(
                    Modifier.size(76.dp).background(tint.copy(alpha = 0.12f), RoundedCornerShape(18.dp)),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
                ) {
                    Text(days?.let { "${abs(it)}" } ?: "—", color = tint, fontSize = 30.sp, fontWeight = FontWeight.Black)
                    Text(
                        pluralStringResource(if (late) R.plurals.shipments_days_late_unit else R.plurals.shipments_days_unit, abs(days ?: 0)),
                        color = tint, style = MaterialTheme.typography.labelSmall)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(graph.title(a), style = MaterialTheme.typography.titleLarge)
                    Text(graph.clientName(graph.orderOf(a)), style = MaterialTheme.typography.bodyMedium, color = c.secondary, maxLines = 1)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        PlantPill(graph.plantName(a))
                        Pill(stringResource(R.string.shipments_delivery_on, Fmt.shortDate(graph.clientDate(a))), c.secondary, Icons.Filled.CalendarMonth)
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row {
                    Text(stringResource(R.string.shipments_shipped_of, Fmt.int(metrics.shipped), Fmt.int(metrics.shippingBase)), style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                    Text(stringResource(R.string.shipments_to_ship_count, Fmt.int(metrics.toShip)), style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                }
                Meter(metrics.shippingProgress, c.brand)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Payments, null, tint = c.secondary, modifier = Modifier.size(18.dp))
                Text(" ${Fmt.money(metrics.revenue)}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                if (canShip) {
                    Button(onShip, colors = ButtonDefaults.buttonColors(containerColor = c.brand, contentColor = Color.White)) {
                        Icon(Icons.AutoMirrored.Filled.Send, null, Modifier.size(16.dp))
                        Text("  " + stringResource(R.string.shipments_record_shipment))
                    }
                }
            }
        }
    }
}
