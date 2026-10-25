package com.nevutech.trama.feature.orders

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.KpiTile
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.tint
import com.nevutech.trama.feature.production.ConfirmDialog
import com.nevutech.trama.feature.production.DaysLeftBadge
import com.nevutech.trama.feature.production.Meter
import com.nevutech.trama.feature.production.OrderFilter
import com.nevutech.trama.feature.production.ScreenHeader
import com.nevutech.trama.feature.production.SearchBox
import com.nevutech.trama.feature.production.isWideLayout
import com.nevutech.trama.feature.production.sortedOrders

/** "Cortes por asignar": every cut order with its assignment progress. */
@Composable
fun OrdersScreen() {
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val app = LocalApp.current
    val actions = rememberActions()
    val wide = isWideLayout()

    var filter by rememberSaveable { mutableStateOf(OrderFilter.Pending) }
    var query by rememberSaveable { mutableStateOf("") }
    var creating by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<CutOrderEntity?>(null) }
    var deleting by remember { mutableStateOf<CutOrderEntity?>(null) }

    val pending = graph.orders.filter { graph.remaining(it) > 0 }
    val garments = pending.sumOf { graph.remaining(it) }
    val value = pending.sumOf { graph.remaining(it) * it.unitPrice }
    val q = query.trim().lowercase()
    val rows = sortedOrders(graph.orders).filter { filter.matches(graph, it) && (q.isEmpty() || graph.searchText(it).contains(q)) }

    TramaScreen {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = if (wide) 24.dp else 16.dp, end = if (wide) 24.dp else 16.dp, bottom = 100.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { ScreenHeader(stringResource(R.string.section_orders), showTitle = wide) }
            item {
                val tiles: List<@Composable (Modifier) -> Unit> = listOf(
                    { KpiTile(stringResource(R.string.orders_kpi_pending_cuts), Fmt.int(pending.size), Icons.Filled.ContentCut, Tokens.colors.danger, modifier = it) },
                    { KpiTile(stringResource(R.string.orders_kpi_garments_to_assign), Fmt.int(garments), Icons.Filled.Checkroom, Tokens.colors.warning, modifier = it) },
                    { KpiTile(stringResource(R.string.orders_kpi_value_to_assign), Fmt.money(value, compact = true), Icons.Filled.Payments, Tokens.colors.brand, modifier = it) },
                )
                if (wide) {
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) { tiles.forEach { it(Modifier.weight(1f)) } }
                } else {
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) { tiles.forEach { it(Modifier.width(210.dp)) } }
                }
            }
            item {
                val controls: @Composable (Modifier) -> Unit = { m ->
                    SingleChoiceSegmentedButtonRow(m) {
                        OrderFilter.entries.forEachIndexed { i, f ->
                            SegmentedButton(filter == f, { filter = f }, SegmentedButtonDefaults.itemShape(i, OrderFilter.entries.size)) { Text(stringResource(f.titleRes), maxLines = 1) }
                        }
                    }
                }
                if (wide) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        controls(Modifier.widthIn(max = 420.dp))
                        SearchBox(query, { query = it }, stringResource(R.string.orders_search_placeholder), Modifier.weight(1f))
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        SearchBox(query, { query = it }, stringResource(R.string.orders_search_placeholder))
                        controls(Modifier.fillMaxWidth())
                    }
                }
            }
            if (rows.isEmpty()) {
                item {
                    if (q.isEmpty()) EmptyState(stringResource(R.string.orders_empty_title), stringResource(R.string.orders_empty_message), Icons.Filled.Verified)
                    else EmptyState(stringResource(R.string.common_no_results), stringResource(R.string.orders_no_results_message), Icons.Filled.SearchOff)
                }
            }
            items(rows, key = { it.id }) { order ->
                OrderRow(graph, order, wide, onOpen = { navigator.openOrder(order.id) }, onEdit = { editing = order }, onDelete = { deleting = order })
            }
        }
        Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.BottomEnd) {
            ExtendedFloatingActionButton(
                onClick = { creating = true }, containerColor = Tokens.colors.brand, contentColor = androidx.compose.ui.graphics.Color.White,
                icon = { Icon(Icons.Filled.Add, null) }, text = { Text(stringResource(R.string.orders_new)) },
            )
        }
    }

    if (creating) OrderEditorSheet(null) { creating = false }
    editing?.let { OrderEditorSheet(it) { editing = null } }
    deleting?.let { order ->
        ConfirmDialog(
            stringResource(R.string.orders_delete_title, order.code), stringResource(R.string.orders_delete_message), stringResource(R.string.common_delete),
            onConfirm = { actions.run(success = L10n.str(R.string.orders_deleted)) { app.production().deleteOrder(order) } },
            onDismiss = { deleting = null },
        )
    }
}

/** Rich order row: swatch, code, list, client · garment · style, state, days left, revenue and progress. */
@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
fun OrderRow(graph: Graph, order: CutOrderEntity, wide: Boolean, onOpen: () -> Unit, onEdit: (() -> Unit)? = null, onDelete: (() -> Unit)? = null) {
    val app = LocalApp.current
    val c = Tokens.colors
    val haptics = LocalHapticFeedback.current
    val state = graph.state(order)
    val assigned = graph.assignedQuantity(order)
    var menu by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(18.dp)
    val openLabel = stringResource(R.string.orders_open)
    val optionsLabel = stringResource(R.string.orders_options)
    val remainingText = stringResource(R.string.orders_remaining_of, Fmt.int(graph.remaining(order)), Fmt.int(order.quantity))
    Row(
        Modifier.fillMaxWidth().background(c.surface, shape).border(1.dp, c.stroke, shape)
            .combinedClickable(
                onClick = onOpen, onClickLabel = openLabel,
                onLongClick = if (onEdit != null) ({ haptics.performHapticFeedback(HapticFeedbackType.LongPress); menu = true }) else null,
                onLongClickLabel = optionsLabel,
            )
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Swatch(graph.styleName(order), app.images.file(graph.style(order.styleId)?.imageFile), Modifier.size(if (wide) 64.dp else 52.dp), corner = 14.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(order.code, style = MaterialTheme.typography.titleMedium)
                Text(stringResource(R.string.orders_list_label, order.list.ifBlank { "—" }), style = MaterialTheme.typography.bodyMedium, color = c.secondary, maxLines = 1)
            }
            Text(
                listOf(graph.clientName(order), order.garment, graph.styleName(order)).filter { it.isNotBlank() }.joinToString(" · "),
                style = MaterialTheme.typography.bodyMedium, color = c.secondary, maxLines = 1,
            )
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Pill(stringResource(state.titleRes), state.tint())
                DaysLeftBadge(order.clientDate?.toLocalDate())
            }
            if (!wide) {
                Text("${Fmt.money(order.quantity * order.unitPrice)} · $remainingText", style = MaterialTheme.typography.bodySmall, color = c.secondary)
                Meter(assigned.toDouble() / maxOf(order.quantity, 1L), state.tint())
            }
        }
        if (wide) {
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(Fmt.money(order.quantity * order.unitPrice), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(remainingText, style = MaterialTheme.typography.bodySmall, color = c.secondary)
                Meter(assigned.toDouble() / maxOf(order.quantity, 1L), state.tint(), Modifier.width(160.dp))
            }
        }
        if (onEdit != null || onDelete != null) {
            Box {
                IconButton({ menu = true }) { Icon(Icons.Filled.MoreVert, stringResource(R.string.orders_options_for, order.code), tint = c.secondary) }
                DropdownMenu(menu, { menu = false }) {
                    onEdit?.let { DropdownMenuItem(text = { Text(stringResource(R.string.common_edit)) }, leadingIcon = { Icon(Icons.Filled.Edit, null) }, onClick = { menu = false; it() }) }
                    onDelete?.let {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.common_delete), color = c.danger) }, leadingIcon = { Icon(Icons.Filled.Delete, null, tint = c.danger) },
                            onClick = { menu = false; it() },
                        )
                    }
                }
            }
        }
    }
}
