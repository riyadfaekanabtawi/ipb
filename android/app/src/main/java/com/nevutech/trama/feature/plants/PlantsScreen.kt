package com.nevutech.trama.feature.plants

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.PersonSearch
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.data.UserEntity
import com.nevutech.trama.core.data.fullName
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.CapacityBar
import com.nevutech.trama.designsystem.DecimalField
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.KpiTile
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.capacityTint
import com.nevutech.trama.feature.clients.AdaptiveRows
import com.nevutech.trama.feature.clients.CardStat
import com.nevutech.trama.feature.clients.CatalogGrid
import com.nevutech.trama.feature.clients.ConfirmDeleteDialog
import com.nevutech.trama.feature.clients.FormSection
import com.nevutech.trama.feature.clients.FormSheet
import com.nevutech.trama.feature.clients.MenuItem
import com.nevutech.trama.feature.clients.NoResults
import com.nevutech.trama.feature.clients.WithContextMenu
import com.nevutech.trama.feature.clients.cardClick
import com.nevutech.trama.feature.clients.catalogMatches
import com.nevutech.trama.feature.clients.fullSpan
import com.nevutech.trama.feature.clients.rememberCatalog
import com.nevutech.trama.feature.clients.rememberToasts
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle

/** Sheet target: a new plant (null) or an existing one. */
data class PlantEditorTarget(val plant: PlantEntity?)

@Composable
fun PlantsScreen() {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    var search by rememberSaveable { mutableStateOf("") }
    var editor by remember { mutableStateOf<PlantEditorTarget?>(null) }
    var pendingDelete by remember { mutableStateOf<PlantEntity?>(null) }

    val plants = graph.plants
    val filtered = plants.filter { p -> catalogMatches(search, listOf(p.name) + graph.managersOf(p).map { it.fullName }) }

    TramaScreen {
        CatalogGrid("Plantas", search, { search = it }, "Buscar planta o gerente", "Nueva planta", { editor = PlantEditorTarget(null) }, minCell = 330.dp) {
            if (plants.isNotEmpty()) fullSpan { PlantsSummary(graph) }
            when {
                plants.isEmpty() -> fullSpan {
                    EmptyState("Sin plantas", "Agrega tus plantas con su capacidad mensual para empezar a asignar cortes.", Icons.Filled.Apartment) {
                        PrimaryButton("Nueva planta", { editor = PlantEditorTarget(null) }, icon = Icons.Filled.Add)
                    }
                }
                filtered.isEmpty() -> fullSpan { NoResults(search) }
                else -> items(filtered.size, key = { filtered[it].id }) { i ->
                    val plant = filtered[i]
                    WithContextMenu(menu = { close ->
                        MenuItem("Editar", Icons.Filled.Edit) { close(); editor = PlantEditorTarget(plant) }
                        MenuItem("Eliminar", Icons.Filled.Delete, destructive = true) { close(); pendingDelete = plant }
                    }) { open ->
                        PlantCard(graph, plant, Modifier.cardClick({ navigator.openPlant(plant.id) }, open))
                    }
                }
            }
        }
    }

    editor?.let { PlantEditorSheet(it.plant, graph) { editor = null } }
    pendingDelete?.let { plant ->
        ConfirmDeleteDialog(
            "¿Eliminar ${plant.name}?", "Solo se pueden eliminar plantas sin cortes asignados.",
            onConfirm = { actions.run(success = "Planta «${plant.name}» eliminada") { app.production().deletePlant(plant) } },
            onDismiss = { pendingDelete = null },
        )
    }
}

/** Assignments of the plant still in progress (garments pending shipment). */
fun Graph.openAssignmentCount(plant: PlantEntity) = assignmentsOf(plant).count { !metrics(it).isComplete }

@Composable
private fun PlantsSummary(graph: Graph) {
    val month = YearMonth.now()
    val capacity = graph.plants.sumOf { it.maxCapacity }
    val used = graph.plants.sumOf { graph.ledger(it).used(month) }
    val active = graph.plants.sumOf { graph.openAssignmentCount(it) }
    val ratio = if (capacity > 0) used / capacity else 0.0
    val tiles: List<@Composable () -> Unit> = listOf(
        { KpiTile("Plantas", Fmt.int(graph.plants.size), Icons.Filled.Apartment) },
        { KpiTile("Capacidad mensual total", Fmt.money(capacity, compact = true), Icons.Filled.Speed, Tokens.colors.info) },
        {
            KpiTile(
                "Usado este mes", Fmt.money(used, compact = true), Icons.Filled.BarChart, capacityTint(ratio.toFloat()),
                footnote = if (capacity > 0) "${Fmt.percent(ratio)} de la capacidad" else null,
            )
        },
        { KpiTile("Asignaciones activas", Fmt.int(active), Icons.Filled.ContentCut, Tokens.colors.thread) },
    )
    AdaptiveRows(tiles, minWidth = 150.dp, spacing = 18.dp) { it() }
}

@Composable
private fun PlantCard(graph: Graph, plant: PlantEntity, modifier: Modifier) {
    val month = YearMonth.now()
    val ledger = graph.ledger(plant)
    val used = ledger.used(month)
    val ratio = ledger.utilization(month)
    TramaCard(modifier.fillMaxWidth().semantics(mergeDescendants = true) {}) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Avatar(plant.name, size = 50.dp, icon = Icons.Filled.Apartment)
            Column(Modifier.weight(1f)) {
                Text(plant.name, style = MaterialTheme.typography.titleLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("Capacidad ${Fmt.money(plant.maxCapacity, compact = true)} al mes", style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, maxLines = 1)
            }
            Text(Fmt.percent(ratio), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = capacityTint(ratio.toFloat()))
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row {
                Text(monthName(LocalDate.now()), style = MaterialTheme.typography.labelMedium, modifier = Modifier.weight(1f))
                Text("Disponible ${Fmt.money(maxOf(0.0, ledger.available(month)), compact = true)}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
            }
            CapacityBar(used, plant.maxCapacity)
            Text("Usado ${Fmt.money(used, compact = true)}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
        }
        HorizontalDivider(color = Tokens.colors.stroke)
        Row(verticalAlignment = Alignment.CenterVertically) {
            CardStat(Icons.Filled.ContentCut, Fmt.int(graph.openAssignmentCount(plant)), "activas", Tokens.colors.thread)
            Spacer(Modifier.weight(1f))
            ManagersStack(graph.managersOf(plant).sortedBy { it.fullName })
        }
    }
}

fun monthName(date: LocalDate): String =
    date.month.getDisplayName(TextStyle.FULL_STANDALONE, Fmt.locale).replaceFirstChar { it.titlecase(Fmt.locale) }

/** Overlapping avatars of a plant's managers. */
@Composable
fun ManagersStack(managers: List<UserEntity>) {
    val images = LocalApp.current.images
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (managers.isEmpty()) {
            Icon(Icons.Outlined.PersonSearch, null, tint = Tokens.colors.secondary.copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
            Text("Sin gerente", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary.copy(alpha = 0.6f))
        } else {
            Box {
                managers.take(3).forEachIndexed { i, user ->
                    Box(Modifier.offset(x = (i * 20).dp).border(2.dp, Tokens.colors.surface, RoundedCornerShape(9.dp))) {
                        Avatar(user.fullName, images.file(user.avatarFile), size = 30.dp)
                    }
                }
                Spacer(Modifier.size(width = (30 + 20 * (minOf(3, managers.size) - 1)).dp, height = 30.dp))
            }
            Text(
                if (managers.size == 1) managers[0].fullName else "${managers.size} gerentes",
                style = MaterialTheme.typography.labelMedium, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
fun PlantEditorSheet(plant: PlantEntity?, graph: Graph, onDismiss: () -> Unit) {
    val catalog = rememberCatalog()
    val actions = rememberActions()
    val toasts = rememberToasts()
    var name by remember { mutableStateOf(plant?.name ?: "") }
    var capacity by remember { mutableDoubleStateOf(plant?.maxCapacity ?: 0.0) }

    FormSheet(
        if (plant == null) "Nueva planta" else "Editar planta", onDismiss,
        onSave = {
            actions.run(onDone = onDismiss) {
                val saved = catalog.savePlant(plant, name, capacity)
                toasts.show(if (plant == null) "Planta «${saved.name}» creada" else "Planta actualizada")
            }
        },
        canSave = name.isNotBlank() && capacity > 0,
    ) {
        FormSection("Planta", footer = "La capacidad se mide en pesos por mes: cada asignación consume cantidad × precio unitario.") {
            TramaField(name, { name = it }, "Nombre")
            DecimalField(capacity, { capacity = it }, "Capacidad máxima mensual")
        }
        if (plant != null && plant.maxCapacity > 0) {
            val used = graph.ledger(plant).used(YearMonth.now())
            FormSection("Este mes") {
                CapacityBar(used, capacity)
                Row {
                    Text("Usado ${Fmt.money(used)}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, modifier = Modifier.weight(1f))
                    Text("Disponible ${Fmt.money(maxOf(0.0, capacity - used))}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                }
                if (used > capacity) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.semantics(mergeDescendants = true) { contentDescription = "Advertencia" }) {
                        Icon(Icons.Filled.Warning, null, tint = Tokens.colors.warning, modifier = Modifier.size(16.dp))
                        Text("La nueva capacidad es menor a lo ya asignado este mes.", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.warning)
                    }
                }
            }
        }
    }
}
