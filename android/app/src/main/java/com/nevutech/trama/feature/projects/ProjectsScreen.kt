package com.nevutech.trama.feature.projects

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Percent
import androidx.compose.material.icons.filled.Texture
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.ViewWeek
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.ClientEntity
import com.nevutech.trama.core.data.ProjectDraft
import com.nevutech.trama.core.data.ProjectEntity
import com.nevutech.trama.core.data.statusValue
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.data.total
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.UrgencyPolicy
import com.nevutech.trama.designsystem.DecimalField
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.IntField
import com.nevutech.trama.designsystem.KpiTile
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.feature.clients.AdaptiveRows
import com.nevutech.trama.feature.clients.CardStat
import com.nevutech.trama.feature.clients.CatalogGrid
import com.nevutech.trama.feature.clients.ConfirmDeleteDialog
import com.nevutech.trama.feature.clients.DateRow
import com.nevutech.trama.feature.clients.FormSection
import com.nevutech.trama.feature.clients.FormSheet
import com.nevutech.trama.feature.clients.MenuItem
import com.nevutech.trama.feature.clients.PickerField
import com.nevutech.trama.feature.clients.Segmented
import com.nevutech.trama.feature.clients.WithContextMenu
import com.nevutech.trama.feature.clients.cardClick
import com.nevutech.trama.feature.clients.catalogMatches
import com.nevutech.trama.feature.clients.displayTint
import com.nevutech.trama.feature.clients.fullSpan
import com.nevutech.trama.feature.clients.icon
import com.nevutech.trama.feature.clients.rememberCatalog
import com.nevutech.trama.feature.styles.PhotoField
import com.nevutech.trama.feature.styles.PhotoPreview
import com.nevutech.trama.core.data.ImageEdit
import java.time.LocalDate

private enum class ProjectsLayout { Board, Grid }

/** Sheet target: a new project (null) or an existing one. */
private data class ProjectEditorTarget(val project: ProjectEntity?)

/** Quotes / prospects pipeline: pending → accepted or declined. */
@Composable
fun ProjectsScreen() {
    val graph by rememberGraph()
    val actions = rememberActions()
    val catalog = rememberCatalog()
    var layout by rememberSaveable { mutableStateOf(ProjectsLayout.Board) }
    var filter by rememberSaveable { mutableStateOf<ProjectStatus?>(null) }
    var search by rememberSaveable { mutableStateOf("") }
    var editor by remember { mutableStateOf<ProjectEditorTarget?>(null) }
    var pendingDelete by remember { mutableStateOf<ProjectEntity?>(null) }

    val projects = graph.projects
    val matching = projects.filter { catalogMatches(search, listOf(it.displayClient, it.fabric, it.notes)) }

    fun setStatus(project: ProjectEntity, status: ProjectStatus) {
        if (project.statusValue == status) return
        actions.run(success = "Proyecto de ${project.displayClient}: ${status.title.lowercase()}") { catalog.setProjectStatus(project, status) }
    }

    @Composable
    fun Card(project: ProjectEntity, compact: Boolean) {
        WithContextMenu(menu = { close ->
            MenuItem("Editar", Icons.Filled.Edit) { close(); editor = ProjectEditorTarget(project) }
            ProjectStatus.entries.forEach { status ->
                MenuItem("Marcar como ${status.title.lowercase()}", status.icon, enabled = project.statusValue != status) { close(); setStatus(project, status) }
            }
            HorizontalDivider()
            MenuItem("Eliminar", Icons.Filled.Delete, destructive = true) { close(); pendingDelete = project }
        }) { open ->
            ProjectCard(project, compact, Modifier.cardClick({ editor = ProjectEditorTarget(project) }, open)) { setStatus(project, it) }
        }
    }

    TramaScreen {
        CatalogGrid(
            "Proyectos", search, { search = it }, "Buscar cliente, tela o notas", "Nuevo proyecto", { editor = ProjectEditorTarget(null) },
            minCell = 300.dp,
            actions = {
                IconButton({ layout = if (layout == ProjectsLayout.Board) ProjectsLayout.Grid else ProjectsLayout.Board }) {
                    if (layout == ProjectsLayout.Board) Icon(Icons.Filled.GridView, "Vista: tablero. Cambiar a cuadrícula")
                    else Icon(Icons.Filled.ViewWeek, "Vista: cuadrícula. Cambiar a tablero")
                }
            },
        ) {
            if (projects.isEmpty()) {
                fullSpan {
                    EmptyState("Sin proyectos", "Registra cotizaciones y prospectos para darles seguimiento hasta que se acepten.", Icons.Filled.Folder) {
                        PrimaryButton("Nuevo proyecto", { editor = ProjectEditorTarget(null) }, icon = Icons.Filled.Add)
                    }
                }
                return@CatalogGrid
            }
            fullSpan {
                Pipeline(projects, filter) { status ->
                    filter = if (filter == status) null else status
                    if (filter != null) layout = ProjectsLayout.Grid
                }
            }
            if (layout == ProjectsLayout.Board && filter == null) {
                fullSpan { Board(matching) { p, compact -> Card(p, compact) } }
            } else {
                fullSpan {
                    Segmented(
                        listOf<ProjectStatus?>(null) + ProjectStatus.entries, filter,
                        { s -> if (s == null) "Todos (${matching.size})" else "${s.title} (${matching.count { it.statusValue == s }})" },
                        { filter = it }, Modifier.widthIn(max = 640.dp).fillMaxWidth(),
                    )
                }
                val items = matching.filter { filter == null || it.statusValue == filter }
                if (items.isEmpty()) {
                    fullSpan {
                        EmptyState(
                            if (search.isBlank()) "Nada por aquí" else "Sin resultados",
                            if (search.isBlank()) "No hay proyectos con este estado." else "Prueba con otra búsqueda.", Icons.Filled.Folder,
                        )
                    }
                } else {
                    items(items.size, key = { items[it].id }) { i -> Card(items[i], compact = false) }
                }
            }
        }
    }

    editor?.let { ProjectEditorSheet(it.project, graph.clients) { editor = null } }
    pendingDelete?.let { project ->
        ConfirmDeleteDialog(
            "¿Eliminar este proyecto?", project.displayClient,
            onConfirm = { actions.run(success = "Proyecto eliminado") { catalog.deleteProject(project) } },
            onDismiss = { pendingDelete = null },
        )
    }
}

private val ProjectEntity.displayClient: String get() = clientName?.takeIf { it.isNotBlank() } ?: "Sin cliente"

@Composable
private fun Pipeline(projects: List<ProjectEntity>, filter: ProjectStatus?, onTap: (ProjectStatus) -> Unit) {
    val accepted = projects.count { it.statusValue == ProjectStatus.Accepted }
    val decided = projects.count { it.statusValue != ProjectStatus.Pending }
    // null stands for the acceptance-rate tile.
    AdaptiveRows(ProjectStatus.entries + listOf<ProjectStatus?>(null), minWidth = 150.dp, spacing = 18.dp) { status ->
        if (status != null) {
            val group = projects.filter { it.statusValue == status }
            KpiTile(
                status.title, Fmt.money(group.sumOf { it.total }, compact = true), status.icon, status.displayTint(),
                footnote = (if (group.size == 1) "1 proyecto" else "${group.size} proyectos") + if (filter == status) " · filtrando" else "",
                onClick = { onTap(status) },
            )
        } else {
            KpiTile(
                "Tasa de aceptación", if (decided > 0) Fmt.percent(accepted.toDouble() / decided) else "—", Icons.Filled.Percent,
                Tokens.colors.info, footnote = "De los proyectos ya decididos",
            )
        }
    }
}

@Composable
private fun Board(projects: List<ProjectEntity>, card: @Composable (ProjectEntity, Boolean) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val columns: @Composable (Modifier) -> Unit = { m ->
            ProjectStatus.entries.forEach { status -> ProjectColumn(status, projects.filter { it.statusValue == status }, m, card) }
        }
        if (maxWidth > 760.dp) Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) { columns(Modifier.weight(1f)) }
        else Column(verticalArrangement = Arrangement.spacedBy(16.dp)) { columns(Modifier.fillMaxWidth()) }
    }
}

/** One status column of the board. */
@Composable
private fun ProjectColumn(status: ProjectStatus, projects: List<ProjectEntity>, modifier: Modifier, card: @Composable (ProjectEntity, Boolean) -> Unit) {
    val tint = status.displayTint()
    Column(
        modifier.clip(Tokens.cardShape).background(tint.copy(alpha = 0.06f)).padding(12.dp).animateContentSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Pill(status.title, tint, status.icon)
            Text("${projects.size}", style = MaterialTheme.typography.labelLarge, color = Tokens.colors.secondary)
            Spacer(Modifier.weight(1f))
            Text(Fmt.money(projects.sumOf { it.total }, compact = true), style = MaterialTheme.typography.labelLarge)
        }
        projects.forEach { card(it, true) }
        if (projects.isEmpty()) {
            Box(Modifier.fillMaxWidth().heightIn(min = 90.dp), contentAlignment = Alignment.Center) {
                Text("Sin proyectos en este estado", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary.copy(alpha = 0.6f))
            }
        }
    }
}

@Composable
private fun ProjectCard(project: ProjectEntity, compact: Boolean, modifier: Modifier, changeStatus: (ProjectStatus) -> Unit) {
    val images = LocalApp.current.images
    val photo = images.file(project.photoFile)
    TramaCard(modifier.fillMaxWidth(), padding = if (compact) 14.dp else 18.dp) {
        if (photo != null || !compact) {
            PhotoPreview(project.fabric ?: project.displayClient, photo, ImageEdit.Keep, Modifier.fillMaxWidth().height(if (compact) 110.dp else 150.dp))
        }
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(project.displayClient, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Filled.CalendarMonth, null, tint = Tokens.colors.secondary, modifier = Modifier.size(14.dp))
                    Text(Fmt.relativeDays(UrgencyPolicy.daysLeft(project.deliveryDate?.toLocalDate())), style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1)
                }
            }
            // On the board the column already shows the status, so only the switcher icon is needed.
            StatusMenu(project.statusValue, iconOnly = compact, change = changeStatus)
        }
        Column {
            Text(Fmt.money(project.total), fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text("${Fmt.int(project.quantity)} prendas × ${Fmt.money(project.price)}", style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
        }
        if (!compact) {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                CardStat(Icons.Filled.Timer, "${Fmt.number(project.minutes)} min", "minutaje", Tokens.colors.info)
                CardStat(Icons.Filled.Texture, project.fabric ?: "—", "tela", Tokens.colors.thread)
            }
            project.notes?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        } else project.fabric?.let { fabric ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Filled.Texture, null, tint = Tokens.colors.secondary, modifier = Modifier.size(14.dp))
                Text(fabric, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1)
            }
        }
    }
}

/** Status pill that doubles as a quick status switcher (replaces the legacy "approve" button). */
@Composable
private fun StatusMenu(status: ProjectStatus, iconOnly: Boolean, change: (ProjectStatus) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        val label = "Estado: ${status.title}. Cambiar estado"
        if (iconOnly) {
            IconButton({ open = true }, Modifier.size(36.dp)) { Icon(Icons.Filled.Autorenew, label, tint = Tokens.colors.brand) }
        } else {
            Row(
                Modifier.clip(Tokens.chipShape).clickable(role = Role.Button) { open = true }.semantics(mergeDescendants = true) { contentDescription = label },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Pill(status.title, status.displayTint(), status.icon)
                Icon(Icons.Filled.KeyboardArrowDown, null, tint = Tokens.colors.secondary.copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
            }
        }
        DropdownMenu(open, { open = false }) {
            ProjectStatus.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.title) }, onClick = { open = false; change(option) },
                    leadingIcon = { if (option == status) Icon(Icons.Filled.Check, null) else Spacer(Modifier.size(24.dp)) },
                )
            }
        }
    }
}

@Composable
private fun ProjectEditorSheet(project: ProjectEntity?, clients: List<ClientEntity>, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val catalog = rememberCatalog()
    val actions = rememberActions()
    var draft by remember { mutableStateOf(project?.let(ProjectDraft::of) ?: ProjectDraft()) }
    var hasDelivery by remember { mutableStateOf(project?.deliveryDate != null) }
    var delivery by remember { mutableStateOf(project?.deliveryDate?.toLocalDate() ?: LocalDate.now().plusMonths(1)) }
    val hasClient = draft.clientId != null || draft.clientName.isNotBlank()
    val currentPhoto = app.images.file(project?.photoFile)

    FormSheet(
        if (project == null) "Nuevo proyecto" else "Editar proyecto", onDismiss,
        onSave = {
            val toSave = draft.copy(deliveryDate = if (hasDelivery) delivery else null)
            actions.run(success = if (project == null) "Proyecto creado" else "Proyecto actualizado", onDone = onDismiss) {
                catalog.saveProject(project, toSave)
            }
        },
        canSave = hasClient,
    ) {
        FormSection("Cliente") {
            val selected = clients.firstOrNull { it.id == draft.clientId }
            PickerField("Cliente", listOf<ClientEntity?>(null) + clients, selected, { it?.name ?: "Otro (escribir nombre)" }, { draft = draft.copy(clientId = it?.id) })
            if (selected == null) TramaField(draft.clientName, { draft = draft.copy(clientName = it) }, "Nombre del cliente o prospecto")
        }
        FormSection("Cotización") {
            IntField(draft.quantity.toInt(), { draft = draft.copy(quantity = it.toLong()) }, "Cantidad (prendas)")
            DecimalField(draft.price, { draft = draft.copy(price = it) }, "Precio por prenda")
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Total", modifier = Modifier.weight(1f))
                Text(Fmt.money(draft.total), style = MaterialTheme.typography.titleMedium, color = Tokens.colors.brand)
            }
        }
        FormSection(
            "Producción",
            footer = if (draft.minutes > 0 && draft.quantity > 0) "Carga estimada: ${Fmt.number(draft.minutes * draft.quantity / 60)} horas de costura." else null,
        ) {
            DecimalField(draft.minutes, { draft = draft.copy(minutes = it) }, "Minutaje (min por prenda)")
            TramaField(draft.fabric, { draft = draft.copy(fabric = it) }, "Tela")
        }
        FormSection("Seguimiento") {
            Segmented(ProjectStatus.entries, draft.status, { it.title }, { draft = draft.copy(status = it) }, Modifier.fillMaxWidth())
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Fecha de entrega", modifier = Modifier.weight(1f))
                Switch(hasDelivery, { hasDelivery = it })
            }
            if (hasDelivery) DateRow("Entrega", delivery) { delivery = it }
            TramaField(draft.notes, { draft = draft.copy(notes = it) }, "Notas", singleLine = false)
        }
        FormSection("Foto o muestra") {
            PhotoField(draft.fabric.ifBlank { "Proyecto" }, currentPhoto, draft.photo) { draft = draft.copy(photo = it) }
        }
    }
}
