package com.nevutech.trama.feature.reports

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.FilterAltOff
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Iron
import androidx.compose.material.icons.filled.Numbers
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.PrecisionManufacturing
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Warehouse
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.nevutech.trama.BuildConfig
import com.nevutech.trama.R
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ProductionTotals
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.feature.orders.DateField
import com.nevutech.trama.feature.production.CutStatusPill
import com.nevutech.trama.feature.production.FilterChipButton
import com.nevutech.trama.feature.production.FilterMenuChip
import com.nevutech.trama.feature.production.IconTile
import com.nevutech.trama.feature.production.ProductionCsv
import com.nevutech.trama.feature.production.ProductionFilter
import com.nevutech.trama.feature.production.ProductionRow
import com.nevutech.trama.feature.production.ProductionSort
import com.nevutech.trama.feature.production.ScreenHeader
import com.nevutech.trama.feature.production.SearchBox
import com.nevutech.trama.feature.production.StageTints
import com.nevutech.trama.feature.production.icon
import com.nevutech.trama.feature.production.isWideLayout
import com.nevutech.trama.feature.production.productionRows
import java.io.File
import java.time.LocalDate

/** "Reportes de producción": every cut in production with filters, live totals, sorting and CSV export. */
@Composable
fun ProductionReportsScreen() {
    val graph by rememberGraph()
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val user by app.session.user.collectAsState()
    val role = Role.fromRaw(user?.role)
    val isPlantManager = role == Role.PlantManager
    val wide = isWideLayout()

    var query by rememberSaveable { mutableStateOf("") }
    var plantId by rememberSaveable { mutableStateOf<String?>(null) }
    var clientId by rememberSaveable { mutableStateOf<String?>(null) }
    var status by rememberSaveable { mutableStateOf<CutStatus?>(null) }
    var onlyPending by rememberSaveable { mutableStateOf(false) }
    var useDateRange by rememberSaveable { mutableStateOf(false) }
    var from by remember { mutableStateOf(LocalDate.now().minusMonths(1)) }
    var to by remember { mutableStateOf(LocalDate.now().plusMonths(2)) }
    var sort by rememberSaveable { mutableStateOf(ProductionSort.ClientDate) }
    var descending by rememberSaveable { mutableStateOf(false) }
    var showDates by remember { mutableStateOf(false) }

    val filter = ProductionFilter(
        query, if (isPlantManager) null else plantId, clientId, status, onlyPending,
        if (useDateRange) from else null, if (useDateRange) to else null,
    )
    val rows = productionRows(graph, graph.visibleAssignments(user), filter, sort, descending)
    val totals = ProductionTotals.of(rows.map { it.metrics })
    val plantName = graph.plant(user?.plantId)?.name
    val title = if (isPlantManager) stringResource(R.string.reports_title_plant, plantName ?: stringResource(R.string.graph_no_plant))
    else stringResource(R.string.section_production)

    TramaScreen {
        if (isPlantManager && plantName == null) {
            Column {
                ScreenHeader(title, showTitle = wide)
                EmptyState(stringResource(R.string.reports_no_plant_title), stringResource(R.string.reports_no_plant_message), Icons.Filled.Apartment)
            }
            return@TramaScreen
        }
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(title, showTitle = wide || isPlantManager) {
                SortMenu(sort, descending, { sort = it }, { descending = it })
                IconButton({ runCatching { shareCsv(context, rows) }.onFailure(app.toasts::error) }, enabled = rows.isNotEmpty()) {
                    Icon(Icons.Filled.Share, stringResource(R.string.reports_export_csv), tint = if (rows.isNotEmpty()) Tokens.colors.brand else Tokens.colors.secondary)
                }
            }
            Column(Modifier.padding(horizontal = if (wide) 24.dp else 16.dp)) {
                SearchBox(query, { query = it }, stringResource(R.string.reports_search_placeholder))
            }
            // Filters
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = if (wide) 24.dp else 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                val allFem = stringResource(R.string.common_all_fem)
                val allMasc = stringResource(R.string.common_all_masc)
                if (!isPlantManager) {
                    FilterMenuChip(
                        graph.plant(plantId)?.name ?: stringResource(R.string.common_plant), Icons.Filled.Apartment, plantId != null,
                        listOf<Pair<String, () -> Unit>>(allFem to { plantId = null }) + graph.plants.sortedBy { it.name.lowercase() }.map { p -> p.name to { plantId = p.id } },
                    )
                }
                FilterMenuChip(
                    graph.client(clientId)?.name ?: stringResource(R.string.common_client), Icons.Filled.Groups, clientId != null,
                    listOf<Pair<String, () -> Unit>>(allMasc to { clientId = null }) + graph.clients.sortedBy { it.name.lowercase() }.map { c -> c.name to { clientId = c.id } },
                )
                FilterMenuChip(
                    status?.let { stringResource(it.titleRes) } ?: stringResource(R.string.common_status), Icons.Filled.ContentCut, status != null,
                    listOf<Pair<String, () -> Unit>>(allMasc to { status = null }) + CutStatus.entries.map { s -> s.title to { status = s } },
                )
                FilterChipButton(
                    if (useDateRange) stringResource(R.string.reports_date_range, Fmt.shortDate(from), Fmt.shortDate(to)) else stringResource(R.string.common_client_date),
                    Icons.Filled.CalendarMonth, useDateRange, { showDates = true },
                )
                FilterChipButton(stringResource(R.string.reports_filter_pending_shipment), Icons.Filled.Inventory2, onlyPending, { onlyPending = !onlyPending })
                if (filter.isActive) {
                    TextButton({ plantId = null; clientId = null; status = null; onlyPending = false; useDateRange = false; query = "" }) {
                        Icon(Icons.Filled.Cancel, null, tint = Tokens.colors.danger)
                        Text(" " + stringResource(R.string.reports_clear_filters), color = Tokens.colors.danger, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
            TotalsStrip(totals, wide)
            if (rows.isEmpty()) {
                if (filter.isActive) EmptyState(stringResource(R.string.common_no_results), stringResource(R.string.reports_no_results_message), Icons.Filled.FilterAltOff)
                else EmptyState(stringResource(R.string.reports_empty_title), stringResource(R.string.reports_empty_message), Icons.Filled.BarChart)
            } else {
                LazyColumn(
                    Modifier.weight(1f),
                    contentPadding = PaddingValues(start = if (wide) 24.dp else 16.dp, end = if (wide) 24.dp else 16.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(rows, key = { it.id }) { row -> ProductionRowView(row) { navigator.openAssignment(row.id) } }
                }
            }
        }
    }

    if (showDates) {
        AlertDialog(
            onDismissRequest = { showDates = false },
            title = { Text(stringResource(R.string.common_client_date)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.reports_filter_by_client_date), Modifier.weight(1f))
                        Switch(useDateRange, { useDateRange = it })
                    }
                    DateField(stringResource(R.string.reports_date_from), from) { from = it; if (to.isBefore(it)) to = it }
                    DateField(stringResource(R.string.reports_date_to), to) { to = if (it.isBefore(from)) from else it }
                }
            },
            confirmButton = { TextButton({ showDates = false }) { Text(stringResource(R.string.common_done)) } },
        )
    }
}

@Composable
private fun SortMenu(sort: ProductionSort, descending: Boolean, onSort: (ProductionSort) -> Unit, onDescending: (Boolean) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton({ open = true }) { Icon(Icons.AutoMirrored.Filled.Sort, stringResource(R.string.reports_sort), tint = Tokens.colors.brand) }
        DropdownMenu(open, { open = false }) {
            Text(stringResource(R.string.reports_sort_by), style = MaterialTheme.typography.labelMedium, color = Tokens.colors.secondary, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
            ProductionSort.entries.forEach { key ->
                DropdownMenuItem(
                    text = { Text(key.title) }, onClick = { onSort(key); open = false },
                    trailingIcon = if (key == sort) ({ Icon(Icons.Filled.Check, null, tint = Tokens.colors.brand) }) else null,
                )
            }
            HorizontalDivider()
            DropdownMenuItem(
                text = { Text(stringResource(R.string.reports_sort_ascending)) }, onClick = { onDescending(false); open = false },
                trailingIcon = if (!descending) ({ Icon(Icons.Filled.Check, null, tint = Tokens.colors.brand) }) else null,
            )
            DropdownMenuItem(
                text = { Text(stringResource(R.string.reports_sort_descending)) }, onClick = { onDescending(true); open = false },
                trailingIcon = if (descending) ({ Icon(Icons.Filled.Check, null, tint = Tokens.colors.brand) }) else null,
            )
        }
    }
}

@Composable
private fun TotalsStrip(t: ProductionTotals, wide: Boolean) {
    val c = Tokens.colors
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = if (wide) 24.dp else 16.dp).padding(bottom = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TotalChip(stringResource(R.string.reports_total_quantity), Fmt.int(t.quantity), Icons.Filled.Numbers, c.brand)
        TotalChip(stringResource(R.string.reports_produced), Fmt.int(t.produced), Icons.Filled.PrecisionManufacturing, c.info)
        TotalChip(stringResource(R.string.reports_ironing), Fmt.int(t.ironing), Icons.Filled.Iron, StageTints.ironing)
        TotalChip(stringResource(R.string.reports_packing), Fmt.int(t.packing), Icons.Filled.Inventory2, StageTints.packing)
        TotalChip(stringResource(R.string.reports_warehouse), Fmt.int(t.warehouse), Icons.Filled.Warehouse, StageTints.warehouse)
        TotalChip(stringResource(R.string.reports_shipped), Fmt.int(t.shipped), Icons.AutoMirrored.Filled.Send, c.success)
        TotalChip(stringResource(R.string.reports_to_ship_total), Fmt.int(t.toShip), Icons.Filled.Schedule, c.warning)
        TotalChip(stringResource(R.string.reports_revenue_total), Fmt.money(t.revenue, compact = true), Icons.Filled.Payments, c.thread)
    }
}

@Composable
private fun TotalChip(title: String, value: String, icon: ImageVector, tint: Color) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier.background(Tokens.colors.surface, shape).border(1.dp, Tokens.colors.stroke, shape).padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        IconTile(icon, tint, 30.dp)
        Column {
            Text(value, style = MaterialTheme.typography.titleSmall)
            Text(title, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
        }
    }
}

/** One production row; shows more metric columns when there is room. */
@Composable
private fun ProductionRowView(row: ProductionRow, onClick: () -> Unit) {
    val c = Tokens.colors
    androidx.compose.material3.Surface(
        onClick = onClick, shape = RoundedCornerShape(16.dp), color = c.surface, border = BorderStroke(1.dp, c.stroke),
        modifier = Modifier.fillMaxWidth(),
    ) {
        BoxWithConstraints(Modifier.padding(14.dp)) {
            val full = maxWidth >= 820.dp
            val inline = maxWidth >= 520.dp
            val info: @Composable (Modifier) -> Unit = { m ->
                Column(m, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(row.code, style = MaterialTheme.typography.titleMedium)
                        Text(row.plant, style = MaterialTheme.typography.labelMedium, color = Tokens.accent(row.plant), maxLines = 1)
                    }
                    Text(stringResource(R.string.reports_row_client_list, row.client, row.list), style = MaterialTheme.typography.bodySmall, color = c.secondary, maxLines = 1)
                    CutStatusPill(row.status)
                }
            }
            val metrics: @Composable () -> Unit = {
                Row(horizontalArrangement = Arrangement.spacedBy(if (inline) 18.dp else 10.dp)) {
                    Metric(stringResource(R.string.common_quantity), Fmt.int(row.quantity))
                    if (full) {
                        Metric(stringResource(R.string.reports_cut_done), Fmt.int(row.realCut))
                        Metric(stringResource(R.string.reports_produced), Fmt.int(row.produced))
                        Metric(stringResource(R.string.reports_shipped), Fmt.int(row.shipped))
                    }
                    Metric(stringResource(R.string.reports_to_ship), Fmt.int(row.toShip), if (row.toShip > 0) c.warning else c.success)
                    Metric(stringResource(R.string.reports_delivery), row.clientDate?.let { Fmt.shortDate(it) } ?: "—")
                    if (full) Metric(stringResource(R.string.reports_revenue), Fmt.money(row.revenue, compact = true))
                }
            }
            if (inline) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    info(Modifier.weight(1f).widthIn(min = 180.dp))
                    metrics()
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.secondary.copy(alpha = 0.5f))
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    info(Modifier.fillMaxWidth())
                    metrics()
                }
            }
        }
    }
}

@Composable
private fun Metric(title: String, value: String, tint: Color = Tokens.colors.ink, minWidth: Dp = 60.dp) {
    Column(Modifier.widthIn(min = minWidth), horizontalAlignment = Alignment.End) {
        Text(value, style = MaterialTheme.typography.titleSmall, color = tint, maxLines = 1)
        Text(title, style = MaterialTheme.typography.labelSmall, color = Tokens.colors.secondary, maxLines = 1)
    }
}

/** Writes the CSV to cacheDir/exports and opens the share sheet through the app's FileProvider. */
private fun shareCsv(context: Context, rows: List<ProductionRow>) {
    val dir = File(context.cacheDir, "exports").apply { mkdirs() }
    val file = File(dir, ProductionCsv.FILE_NAME)
    file.writeBytes(ProductionCsv.bytes(rows))
    val uri = FileProvider.getUriForFile(context, "${BuildConfig.APPLICATION_ID}.files", file)
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_SUBJECT, L10n.str(R.string.reports_share_subject))
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(send, L10n.str(R.string.reports_export_csv)))
}
