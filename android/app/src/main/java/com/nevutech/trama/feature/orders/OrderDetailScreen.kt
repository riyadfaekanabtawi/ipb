package com.nevutech.trama.feature.orders

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CallSplit
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.EventAvailable
import androidx.compose.material.icons.filled.Numbers
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.InfoRow
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.ProgressRing
import com.nevutech.trama.designsystem.SectionHeader
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.tint
import com.nevutech.trama.feature.production.ConfirmDialog
import com.nevutech.trama.feature.production.CutStatusPill
import com.nevutech.trama.feature.production.DaysLeftBadge
import com.nevutech.trama.feature.production.ScreenHeader
import com.nevutech.trama.feature.production.isWideLayout
import com.nevutech.trama.feature.production.toPluralCount

/** Cut order detail: summary, assignment progress, assignments per plant and the assign action. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OrderDetailScreen(id: String) {
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val app = LocalApp.current
    val actions = rememberActions()
    val wide = isWideLayout()

    var assigning by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf(false) }
    var zoom by remember { mutableStateOf(false) }
    var unassigning by remember { mutableStateOf<AssignmentEntity?>(null) }

    val order = graph.order(id)
    TramaScreen {
        if (order == null) {
            Column {
                ScreenHeader(stringResource(R.string.common_cut), onBack = { navigator.back() })
                EmptyState(stringResource(R.string.assignment_not_found), stringResource(R.string.assignment_not_found_message), Icons.Filled.SearchOff)
            }
            return@TramaScreen
        }
        val state = graph.state(order)
        val remaining = graph.remaining(order)
        val styleFile = app.images.file(graph.style(order.styleId)?.imageFile)

        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.production_cut_title, order.code), onBack = { navigator.back() }) {
                IconButton({ editing = true }) { Icon(Icons.Filled.Edit, stringResource(R.string.common_edit), tint = Tokens.colors.brand) }
                if (wide) {
                    PrimaryButton(stringResource(R.string.orders_assign_to_plant), { assigning = true }, enabled = remaining > 0, icon = Icons.AutoMirrored.Filled.CallSplit)
                } else {
                    IconButton({ assigning = true }, enabled = remaining > 0) { Icon(Icons.AutoMirrored.Filled.CallSplit, stringResource(R.string.orders_assign_to_plant), tint = Tokens.colors.brand) }
                }
            }
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = if (wide) 24.dp else 16.dp).padding(bottom = 24.dp)
                    .widthIn(max = 1200.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                // Header
                TramaCard {
                    Row(horizontalArrangement = Arrangement.spacedBy(20.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(if (wide) 120.dp else 84.dp).clickable(onClickLabel = stringResource(R.string.assignment_view_style_image)) { zoom = true }) {
                            Swatch(graph.styleName(order), styleFile, Modifier.fillMaxSize(), corner = 20.dp)
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(order.code, fontSize = if (wide) 34.sp else 26.sp, fontWeight = FontWeight.Bold)
                                Pill(stringResource(state.titleRes), state.tint(), modifier = Modifier.align(Alignment.CenterVertically))
                            }
                            Text(stringResource(R.string.orders_client_and_list, graph.clientName(order), order.list.ifBlank { "—" }), style = MaterialTheme.typography.titleMedium, color = Tokens.colors.secondary)
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Pill(order.garment.ifBlank { stringResource(R.string.orders_garment_fallback) }, Tokens.colors.brand, Icons.Filled.Checkroom)
                                Pill(graph.styleName(order), Tokens.accent(graph.styleName(order)), Icons.Filled.Palette)
                                DaysLeftBadge(order.clientDate?.toLocalDate())
                            }
                        }
                    }
                }

                val details: @Composable (Modifier) -> Unit = { m ->
                    TramaCard(m) {
                        SectionHeader(stringResource(R.string.orders_detail))
                        InfoRow(stringResource(R.string.common_quantity), Fmt.int(order.quantity), Icons.Filled.Numbers)
                        InfoRow(stringResource(R.string.common_unit_price), Fmt.money(order.unitPrice), Icons.Filled.Sell)
                        InfoRow(stringResource(R.string.orders_total_revenue), Fmt.money(order.quantity * order.unitPrice), Icons.Filled.Payments)
                        InfoRow(stringResource(R.string.common_internal_date), Fmt.date(order.internalDate?.toLocalDate()), Icons.Filled.CalendarMonth)
                        InfoRow(stringResource(R.string.common_client_date), Fmt.date(order.clientDate?.toLocalDate()), Icons.Filled.EventAvailable)
                        order.editedBy?.let { InfoRow(stringResource(R.string.orders_edited_by), it, Icons.Filled.Person) }
                        order.notes?.takeIf { it.isNotBlank() }?.let {
                            Text(it, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, modifier = Modifier.padding(top = 4.dp))
                        }
                    }
                }
                val progress: @Composable (Modifier) -> Unit = { m ->
                    val ratio = if (order.quantity > 0) graph.assignedQuantity(order).toDouble() / order.quantity else 0.0
                    TramaCard(m) {
                        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            Box(Modifier.size(150.dp), contentAlignment = Alignment.Center) {
                                ProgressRing(ratio, Modifier.fillMaxSize(), tint = state.tint(), stroke = 14.dp)
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(Fmt.percent(ratio), fontSize = 30.sp, fontWeight = FontWeight.Bold)
                                    Text(stringResource(R.string.orders_assigned_ring), style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                                }
                            }
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    pluralStringResource(R.plurals.orders_garments_to_assign, remaining.toLong().toPluralCount(), Fmt.int(remaining)),
                                    style = MaterialTheme.typography.titleMedium,
                                )
                                Text(stringResource(R.string.orders_of_total, Fmt.int(order.quantity)), style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
                            }
                            PrimaryButton(stringResource(R.string.orders_assign_to_plant), { assigning = true }, enabled = remaining > 0, icon = Icons.AutoMirrored.Filled.CallSplit)
                        }
                    }
                }
                if (wide) {
                    Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) { details(Modifier.weight(1f)); progress(Modifier.width(300.dp)) }
                } else {
                    details(Modifier.fillMaxWidth()); progress(Modifier.fillMaxWidth())
                }

                TramaCard {
                    SectionHeader(stringResource(R.string.orders_assignments_title), stringResource(R.string.orders_assignments_subtitle))
                    val assignments = graph.assignmentsOf(order).sortedBy { it.scheduledDate ?: Long.MAX_VALUE }
                    if (assignments.isEmpty()) {
                        EmptyState(stringResource(R.string.orders_no_assignments), stringResource(R.string.orders_no_assignments_message), Icons.Filled.Apartment)
                    }
                    assignments.forEach { a ->
                        AssignmentLine(graph, a, onOpen = { navigator.openAssignment(a.id) }, onUnassign = { unassigning = a })
                    }
                }
            }
        }
    }

    if (assigning) AssignSheet(id) { assigning = false }
    if (editing && order != null) OrderEditorSheet(order) { editing = false }
    if (zoom && order != null) {
        Dialog({ zoom = false }) {
            Swatch(graph.styleName(order), app.images.file(graph.style(order.styleId)?.imageFile), Modifier.size(420.dp).clickable { zoom = false }, corner = 24.dp)
        }
    }
    unassigning?.let { a ->
        ConfirmDialog(
            stringResource(R.string.orders_unassign_title), stringResource(R.string.orders_unassign_message), stringResource(R.string.orders_unassign),
            onConfirm = { actions.run(success = L10n.str(R.string.orders_unassigned)) { app.production().unassign(a) } },
            onDismiss = { unassigning = null },
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun AssignmentLine(graph: Graph, a: AssignmentEntity, onOpen: () -> Unit, onUnassign: () -> Unit) {
    val c = Tokens.colors
    var menu by remember { mutableStateOf(false) }
    val plant = graph.plantName(a)
    val optionsLabel = stringResource(R.string.orders_options)
    Row(
        Modifier.fillMaxWidth().background(c.surfaceRaised, RoundedCornerShape(14.dp))
            .combinedClickable(onClick = onOpen, onLongClick = { menu = true }, onLongClickLabel = optionsLabel).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Avatar(plant, size = 44.dp, icon = Icons.Filled.Apartment)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(plant, style = MaterialTheme.typography.titleMedium)
            Text(
                pluralStringResource(
                    R.plurals.orders_assignment_line, a.quantity.toPluralCount(),
                    Fmt.int(a.quantity), Fmt.money(graph.metrics(a).revenue), Fmt.date(a.scheduledDate?.toLocalDate()),
                ),
                style = MaterialTheme.typography.bodyMedium, color = c.secondary,
            )
            if (!isWideLayout()) CutStatusPill(graph.cutStatus(a))
        }
        if (isWideLayout()) CutStatusPill(graph.cutStatus(a))
        Box {
            IconButton({ menu = true }) { Icon(Icons.Filled.MoreVert, stringResource(R.string.orders_assignment_options), tint = c.secondary) }
            DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.orders_unassign), color = c.danger) }, leadingIcon = { Icon(Icons.AutoMirrored.Filled.Undo, null, tint = c.danger) },
                    onClick = { menu = false; onUnassign() },
                )
            }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.secondary.copy(alpha = 0.5f))
    }
}
