package com.nevutech.trama.feature.styles

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.OpenInFull
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.SearchOff
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.StyleEntity
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.KpiTile
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.tint
import com.nevutech.trama.feature.clients.AdaptiveRows
import com.nevutech.trama.feature.clients.CatalogRowCard
import com.nevutech.trama.feature.clients.ConfirmDeleteDialog
import com.nevutech.trama.feature.clients.DetailScaffold
import com.nevutech.trama.feature.clients.MenuItem
import com.nevutech.trama.feature.clients.OverflowMenu
import com.nevutech.trama.feature.clients.SectionTitle
import com.nevutech.trama.feature.clients.rememberCatalog

@Composable
fun StyleDetailScreen(id: String) {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    val catalog = rememberCatalog()
    var editing by remember { mutableStateOf(false) }
    var zooming by remember { mutableStateOf(false) }
    var confirmingDelete by remember { mutableStateOf(false) }

    val style = graph.style(id)
    TramaScreen {
        if (style == null) {
            DetailScaffold(stringResource(R.string.common_style)) { EmptyState(stringResource(R.string.styles_not_found), stringResource(R.string.styles_not_found_message), Icons.Filled.SearchOff) }
            return@TramaScreen
        }
        val orders = graph.ordersOf(style)
        DetailScaffold(style.name, actions = {
            IconButton({ editing = true }) { Icon(Icons.Filled.Edit, stringResource(R.string.common_edit)) }
            OverflowMenu { close -> MenuItem(stringResource(R.string.styles_delete), Icons.Filled.Delete, destructive = true) { close(); confirmingDelete = true } }
        }) {
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val image: @Composable (Modifier) -> Unit = { m -> StyleImage(style, app.images.file(style.imageFile), m) { zooming = true } }
                when {
                    maxWidth > 900.dp -> Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                        image(Modifier.width(420.dp))
                        Summary(graph, style, orders, Modifier.weight(1f))
                    }
                    maxWidth > 620.dp -> Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                        image(Modifier.width(280.dp))
                        Summary(graph, style, orders, Modifier.weight(1f))
                    }
                    else -> Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
                        image(Modifier.widthIn(max = 360.dp).fillMaxWidth())
                        Summary(graph, style, orders, Modifier.fillMaxWidth())
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SectionTitle(
                    stringResource(R.string.styles_orders_title),
                    if (orders.isEmpty()) stringResource(R.string.styles_no_orders) else pluralStringResource(R.plurals.styles_cut_count, orders.size, Fmt.int(orders.size)),
                )
                if (orders.isEmpty()) {
                    TramaCard(Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.styles_orders_empty), color = Tokens.colors.secondary, modifier = Modifier.align(Alignment.CenterHorizontally))
                    }
                } else {
                    orders.forEach { order -> StyleOrderRow(graph, order) { navigator.openOrder(order.id) } }
                }
            }
        }
    }

    if (style != null) {
        if (editing) StyleEditorSheet(style) { editing = false }
        if (zooming) ZoomableImageViewer(app.images.file(style.imageFile), style.name) { zooming = false }
        if (confirmingDelete) {
            ConfirmDeleteDialog(
                stringResource(R.string.styles_delete_title, style.name), stringResource(R.string.styles_delete_message),
                onConfirm = { actions.run(success = L10n.str(R.string.styles_deleted, style.name), onDone = { navigator.back() }) { catalog.deleteStyle(style) } },
                onDismiss = { confirmingDelete = false },
            )
        }
    }
}

@Composable
private fun StyleImage(style: StyleEntity, file: java.io.File?, modifier: Modifier, zoom: () -> Unit) {
    val description = stringResource(R.string.styles_view_fullscreen)
    Box(
        modifier.aspectRatio(4f / 5f).clip(Tokens.cardShape).clickable(role = Role.Button, onClick = zoom)
            .semantics { contentDescription = description },
    ) {
        Swatch(style.name, file, Modifier.fillMaxSize(), corner = 0.dp)
        Box(
            Modifier.align(Alignment.BottomEnd).padding(16.dp).size(40.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.35f)),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Filled.OpenInFull, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Summary(graph: Graph, style: StyleEntity, orders: List<CutOrderEntity>, modifier: Modifier) {
    val navigator = LocalNavigator.current
    val distribution = graph.plantDistribution(style)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(style.name, fontSize = 32.sp, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.styles_registered_on, Fmt.date(style.createdAt.toLocalDate())), color = Tokens.colors.secondary)
        }
        val tiles: List<@Composable () -> Unit> = listOf(
            { KpiTile(stringResource(R.string.common_cuts), Fmt.int(orders.size), Icons.Filled.ContentCut) },
            { KpiTile(stringResource(R.string.common_garments), Fmt.int(orders.sumOf { it.quantity }), Icons.Filled.Checkroom, Tokens.colors.thread) },
            { KpiTile(stringResource(R.string.common_value), Fmt.money(orders.sumOf { it.quantity * it.unitPrice }, compact = true), Icons.Filled.Payments, Tokens.colors.success) },
        )
        AdaptiveRows(tiles, minWidth = 150.dp) { it() }
        TramaCard(Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.styles_assigned_plants), style = MaterialTheme.typography.titleMedium)
            if (distribution.isEmpty()) {
                Text(stringResource(R.string.styles_assigned_plants_empty), style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
            } else {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    distribution.forEach { (plant, count) ->
                        Pill(
                            pluralStringResource(R.plurals.styles_plant_assignments, count, plant.name, Fmt.int(count)), Tokens.accent(plant.name), Icons.Filled.Apartment,
                            Modifier.clip(Tokens.chipShape).clickable(role = Role.Button) { navigator.openPlant(plant.id) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StyleOrderRow(graph: Graph, order: CutOrderEntity, onClick: () -> Unit) {
    val state = graph.state(order)
    CatalogRowCard(onClick) {
        Column(Modifier.weight(1f)) {
            Text(order.code, style = MaterialTheme.typography.titleMedium)
            Text(graph.clientName(order), style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Text(pluralStringResource(R.plurals.styles_garment_count, order.quantity.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(), Fmt.int(order.quantity)), style = MaterialTheme.typography.labelLarge)
        Pill(state.title, state.tint())
    }
}
