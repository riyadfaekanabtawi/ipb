package com.nevutech.trama.feature.production

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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FindInPage
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.ReportEntity
import com.nevutech.trama.core.data.summary
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.Role
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
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val dayFormat = DateTimeFormatter.ofPattern("EEEE d MMM", com.nevutech.trama.core.domain.Fmt.locale)
private val timeFormat = DateTimeFormatter.ofPattern("HH:mm", com.nevutech.trama.core.domain.Fmt.locale)

/** Detail of a cut assigned to a plant: live production funnel, report timeline and role-aware report actions. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AssignmentDetailScreen(id: String) {
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val app = LocalApp.current
    val actions = rememberActions()
    val role = rememberRole()
    val wide = isWideLayout()

    var editor by remember { mutableStateOf<ReportEditorRequest?>(null) }
    var deleting by remember { mutableStateOf<ReportEntity?>(null) }
    var kindFilter by remember { mutableStateOf<ReportKind?>(null) }
    var zoom by remember { mutableStateOf(false) }

    val assignment = graph.assignment(id)
    TramaScreen {
        if (assignment == null) {
            Column {
                ScreenHeader("Corte", onBack = { navigator.back() })
                EmptyState("Corte no encontrado", "Es posible que se haya eliminado.", Icons.Filled.SearchOff)
            }
            return@TramaScreen
        }
        val order = graph.orderOf(assignment)
        val metrics = graph.metrics(assignment)
        val styleFile = app.images.file(graph.style(order?.styleId)?.imageFile)

        Column(Modifier.fillMaxSize()) {
            ScreenHeader("Corte ${graph.title(assignment)}", onBack = { navigator.back() }) {
                AddReportMenu(graph, assignment, role, compact = !wide) { editor = it }
            }
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = if (wide) 24.dp else 16.dp).padding(bottom = 24.dp)
                    .widthIn(max = 1200.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                // Header
                TramaCard {
                    Row(horizontalArrangement = Arrangement.spacedBy(if (wide) 20.dp else 14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(if (wide) 110.dp else 72.dp).clickable(onClickLabel = "Ver imagen del estilo") { zoom = true }) {
                            Swatch(graph.styleName(order), styleFile, Modifier.fillMaxSize(), corner = 20.dp)
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(graph.title(assignment), fontSize = if (wide) 32.sp else 24.sp, fontWeight = FontWeight.Bold)
                                CutStatusPill(graph.cutStatus(assignment), Modifier.align(Alignment.CenterVertically))
                            }
                            Text(
                                "${graph.clientName(order)} · Lista ${order?.list?.ifBlank { null } ?: "—"} · ${order?.garment.orEmpty()}",
                                style = MaterialTheme.typography.titleMedium, color = Tokens.colors.secondary,
                            )
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                PlantPill(graph.plantName(assignment))
                                Pill("Producción ${Fmt.date(assignment.scheduledDate?.toLocalDate())}", Tokens.colors.brand, Icons.Filled.CalendarMonth)
                                DaysLeftBadge(graph.clientDate(assignment))
                            }
                        }
                        if (wide) ShippedRing(metrics.shippingProgress, metrics.isComplete)
                    }
                    if (!wide) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) { ShippedRing(metrics.shippingProgress, metrics.isComplete) }
                }

                val funnel: @Composable (Modifier) -> Unit = { m ->
                    TramaCard(m) {
                        SectionHeader("Avance de producción", "Último reporte de planta, corte real y envíos acumulados")
                        ProductionFunnel(metrics)
                    }
                }
                val stats: @Composable (Modifier) -> Unit = { m ->
                    TramaCard(m) {
                        InfoRow("Por enviar", Fmt.int(metrics.toShip), Icons.Filled.Inventory2)
                        InfoRow("Operarios", Fmt.int(metrics.operators), Icons.Filled.Groups)
                        InfoRow("Faltas", Fmt.int(metrics.absences), Icons.Filled.PersonOff)
                        InfoRow("Precio unitario", Fmt.money(metrics.unitPrice), Icons.Filled.Sell)
                        InfoRow("Ingreso", Fmt.money(metrics.revenue), Icons.Filled.Payments)
                        if (order != null) {
                            OutlinedButton({ navigator.openOrder(order.id) }, Modifier.fillMaxWidth().padding(top = 4.dp)) {
                                Icon(Icons.AutoMirrored.Filled.OpenInNew, null, Modifier.size(18.dp))
                                Text("  Ver corte completo")
                            }
                        }
                    }
                }
                if (wide) {
                    Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) { funnel(Modifier.weight(1f)); stats(Modifier.width(340.dp)) }
                } else {
                    funnel(Modifier.fillMaxWidth()); stats(Modifier.fillMaxWidth())
                }

                // Timeline
                val all = graph.reportsOf(assignment).sortedByDescending { it.createdAt }
                val reports = all.filter { kindFilter == null || ReportKind.fromRaw(it.kind) == kindFilter }
                TramaCard {
                    val picker: @Composable (Modifier) -> Unit = { m ->
                        val options = listOf<ReportKind?>(null) + ReportKind.entries
                        SingleChoiceSegmentedButtonRow(m) {
                            options.forEachIndexed { i, k ->
                                SegmentedButton(kindFilter == k, { kindFilter = k }, SegmentedButtonDefaults.itemShape(i, options.size)) {
                                    Text(k?.shortTitle ?: "Todos", maxLines = 1)
                                }
                            }
                        }
                    }
                    if (wide) {
                        SectionHeader("Reportes", "${all.size} en total") { picker(Modifier.width(360.dp)) }
                    } else {
                        SectionHeader("Reportes", "${all.size} en total")
                        picker(Modifier.fillMaxWidth())
                    }
                    if (reports.isEmpty()) {
                        EmptyState(
                            "Sin reportes", "Los gerentes cargan aquí el avance de planta, el corte real y los envíos.", Icons.Filled.FindInPage,
                        ) { AddReportMenu(graph, assignment, role, compact = false) { editor = it } }
                    }
                    reports.forEach { report ->
                        ReportRow(
                            report, canEdit = role.canEdit(ReportKind.fromRaw(report.kind)),
                            onEdit = { editor = ReportEditorRequest.Edit(assignment.id, report.id) },
                            onDelete = { deleting = report },
                        )
                    }
                }
            }
        }
        if (zoom) {
            Dialog({ zoom = false }) {
                Swatch(graph.styleName(order), styleFile, Modifier.size(420.dp).clickable { zoom = false }, corner = 24.dp)
            }
        }
    }

    editor?.let { request -> androidx.compose.runtime.key(request) { ReportEditorSheet(request) { editor = null } } }
    deleting?.let { report ->
        ConfirmDialog(
            "¿Eliminar este reporte?", null, "Eliminar",
            onConfirm = { actions.run(success = "Reporte eliminado") { app.production().deleteReport(report) } },
            onDismiss = { deleting = null },
        )
    }
}

@Composable
private fun ShippedRing(progress: Double, complete: Boolean) {
    Box(Modifier.size(104.dp), contentAlignment = Alignment.Center) {
        ProgressRing(progress, Modifier.fillMaxSize(), tint = if (complete) Tokens.colors.success else Tokens.colors.brand, stroke = 12.dp)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(Fmt.percent(progress), style = MaterialTheme.typography.titleLarge)
            Text("enviado", style = MaterialTheme.typography.labelSmall, color = Tokens.colors.secondary)
        }
    }
}

/**
 * "Cargar reporte" offering only the kinds this role may create. The cut report is unique, so once
 * it exists the option edits it instead. With a single kind the button acts directly.
 */
@Composable
fun AddReportMenu(graph: Graph, assignment: AssignmentEntity, role: Role, compact: Boolean, onRequest: (ReportEditorRequest) -> Unit) {
    val kinds = role.creatableReports
    if (kinds.isEmpty()) return
    val existingCut = graph.cutReport(assignment)
    fun request(kind: ReportKind): ReportEditorRequest =
        if (kind == ReportKind.Cut && existingCut != null) ReportEditorRequest.Edit(assignment.id, existingCut.id)
        else ReportEditorRequest.New(assignment.id, kind)

    var open by remember { mutableStateOf(false) }
    Box {
        val onClick = { if (kinds.size == 1) onRequest(request(kinds.first())) else open = true }
        if (compact) {
            IconButton(onClick) { Icon(Icons.Filled.Add, "Cargar reporte", tint = Tokens.colors.brand) }
        } else {
            PrimaryButton("Cargar reporte", onClick, icon = Icons.Filled.Add)
        }
        DropdownMenu(open, { open = false }) {
            kinds.forEach { kind ->
                val editsCut = kind == ReportKind.Cut && existingCut != null
                DropdownMenuItem(
                    text = { Text(if (editsCut) "Editar reporte de corte" else kind.title) },
                    leadingIcon = { Icon(if (editsCut) Icons.Filled.Edit else kind.icon, null, tint = kind.tint()) },
                    onClick = { open = false; onRequest(request(kind)) },
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ReportRow(report: ReportEntity, canEdit: Boolean, onEdit: () -> Unit, onDelete: () -> Unit) {
    val c = Tokens.colors
    val kind = ReportKind.fromRaw(report.kind)
    var menu by remember { mutableStateOf(false) }
    val created = Instant.ofEpochMilli(report.createdAt).atZone(ZoneId.systemDefault())
    Row(
        Modifier.fillMaxWidth().background(c.surfaceRaised, RoundedCornerShape(14.dp))
            .let { if (canEdit) it.combinedClickable(onClick = onEdit, onClickLabel = "Editar", onLongClick = { menu = true }) else it }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        IconTile(kind.icon, kind.tint(), 44.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(kind.title, style = MaterialTheme.typography.titleMedium)
            Text(report.summary(), style = MaterialTheme.typography.bodyMedium, color = c.secondary)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(created.format(dayFormat).replaceFirstChar { it.titlecase(Fmt.locale) }, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(listOfNotNull(created.format(timeFormat), report.authorName).joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = c.secondary)
        }
        if (canEdit) {
            Box {
                IconButton({ menu = true }) { Icon(Icons.Filled.MoreVert, "Opciones del reporte", tint = c.secondary) }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem(text = { Text("Editar") }, leadingIcon = { Icon(Icons.Filled.Edit, null) }, onClick = { menu = false; onEdit() })
                    DropdownMenuItem(
                        text = { Text("Eliminar", color = c.danger) }, leadingIcon = { Icon(Icons.Filled.Delete, null, tint = c.danger) },
                        onClick = { menu = false; onDelete() },
                    )
                }
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = c.secondary.copy(alpha = 0.5f))
        }
    }
}
