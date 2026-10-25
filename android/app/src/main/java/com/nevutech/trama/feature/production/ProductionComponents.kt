package com.nevutech.trama.feature.production

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.EventAvailable
import androidx.compose.material.icons.filled.Factory
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Iron
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PrecisionManufacturing
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.TableRestaurant
import androidx.compose.material.icons.filled.Warehouse
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role as SemanticsRole
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.ProductionService
import com.nevutech.trama.core.data.ReportEntity
import com.nevutech.trama.core.domain.AssignmentMetrics
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.domain.UrgencyPolicy
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.IntField
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.tint
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

// Shared building blocks of the production feature screens (orders, board, reports,
// shipments, calendar). Port of ios/Trama/Features/Production/ProductionComponents.swift
// plus the report editor sheet.

// region Environment helpers

/** True on tablets and landscape phones; drives two-column layouts. */
@Composable
fun isWideLayout(minWidth: Int = 600): Boolean = LocalConfiguration.current.screenWidthDp >= minWidth

/** Role of the signed-in user, recomposing when the session changes. */
@Composable
fun rememberRole(): Role {
    val user by LocalApp.current.session.user.collectAsState()
    return Role.fromRaw(user?.role)
}

// endregion

// region Icons and tints

val CutStatus.icon: ImageVector
    get() = when (this) {
        CutStatus.Waiting -> Icons.Filled.Pause
        CutStatus.OnTable -> Icons.Filled.TableRestaurant
        CutStatus.Ready -> Icons.Filled.CheckCircle
    }

val ReportKind.icon: ImageVector
    get() = when (this) {
        ReportKind.Plant -> Icons.Filled.Factory
        ReportKind.Cut -> Icons.Filled.ContentCut
        ReportKind.Shipment -> Icons.Filled.LocalShipping
    }

/**
 * Funnel stage colors. iOS uses fixed orange / violet / cyan for ironing, packing and warehouse;
 * these keys land on exactly those swatches of the [Tokens.accent] palette.
 */
object StageTints {
    val ironing: Color get() = Tokens.accent("a")
    val packing: Color get() = Tokens.accent("e")
    val warehouse: Color get() = Tokens.accent("b")
}

@Composable
fun daysLeftTint(days: Int?): Color = when {
    days == null -> Tokens.colors.secondary
    days < 0 -> Tokens.colors.danger
    days <= 3 -> Tokens.colors.warning
    else -> Tokens.colors.success
}

// endregion

// region Small pieces

@Composable
fun CutStatusPill(status: CutStatus, modifier: Modifier = Modifier) =
    Pill(stringResource(status.titleRes), status.tint(), status.icon, modifier)

/** Days-left chip colored by urgency. */
@Composable
fun DaysLeftBadge(date: LocalDate?, modifier: Modifier = Modifier) {
    val days = UrgencyPolicy.daysLeft(date)
    Pill(Fmt.relativeDays(days), daysLeftTint(days), Icons.Filled.EventAvailable, modifier)
}

/** Screen title row with optional back button and trailing actions (the shell has no app bar on tablets). */
@Composable
fun ScreenHeader(
    title: String,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    showTitle: Boolean = true,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (onBack != null) {
            IconButton(onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.common_back), tint = Tokens.colors.brand) }
        }
        Column(Modifier.weight(1f).padding(start = if (onBack == null) 8.dp else 0.dp)) {
            if (showTitle) {
                Text(title, style = MaterialTheme.typography.headlineSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1)
            }
        }
        actions()
    }
}

/** Search box for list screens. */
@Composable
fun SearchBox(query: String, onQueryChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier) {
    OutlinedTextField(
        query, onQueryChange, modifier.fillMaxWidth(), singleLine = true,
        placeholder = { Text(placeholder) },
        leadingIcon = { Icon(Icons.Filled.Search, null, tint = Tokens.colors.secondary) },
        trailingIcon = if (query.isNotEmpty()) {
            { IconButton({ onQueryChange("") }) { Icon(Icons.Filled.Close, stringResource(R.string.production_clear_search)) } }
        } else null,
        shape = Tokens.chipShape,
        colors = OutlinedTextFieldDefaults.colors(
            unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface,
        ),
    )
}

/** Capsule filter chip (iOS FilterChip): filled brand when active. */
@Composable
fun FilterChipButton(title: String, icon: ImageVector?, active: Boolean, onClick: () -> Unit, chevron: Boolean = false) {
    val c = Tokens.colors
    Surface(
        onClick = onClick, shape = Tokens.chipShape, color = if (active) c.brand else c.surface,
        contentColor = if (active) Color.White else c.ink, border = BorderStroke(1.dp, c.stroke),
    ) {
        Row(Modifier.padding(horizontal = 14.dp, vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            if (icon != null) Icon(icon, null, Modifier.size(16.dp))
            Text(title, style = MaterialTheme.typography.labelLarge, maxLines = 1)
            if (chevron) Icon(Icons.Filled.KeyboardArrowDown, null, Modifier.size(16.dp))
        }
    }
}

/** Filter chip that opens a menu of options. [options] maps a label to its selection callback. */
@Composable
fun FilterMenuChip(title: String, icon: ImageVector?, active: Boolean, options: List<Pair<String, () -> Unit>>) {
    var open by remember { mutableStateOf(false) }
    Box {
        FilterChipButton(title, icon, active, { open = true }, chevron = true)
        DropdownMenu(open, { open = false }) {
            options.forEach { (label, select) ->
                DropdownMenuItem(text = { Text(label) }, onClick = { open = false; select() })
            }
        }
    }
}

/** Thin rounded progress bar. */
@Composable
fun Meter(progress: Double, tint: Color, modifier: Modifier = Modifier, height: Dp = 6.dp) {
    val animated by animateFloatAsState(progress.toFloat().coerceIn(0f, 1f), spring(), label = "meter")
    LinearProgressIndicator(
        progress = { animated }, modifier = modifier.fillMaxWidth().height(height).clip(Tokens.chipShape),
        color = tint, trackColor = tint.copy(alpha = 0.15f), drawStopIndicator = {}, gapSize = 0.dp,
    )
}

/** Rounded square with a tinted icon (report rows, totals, calendar events). */
@Composable
fun IconTile(icon: ImageVector, tint: Color, size: Dp = 40.dp) {
    Box(Modifier.size(size).clip(RoundedCornerShape(size * 0.28f)).background(tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(size * 0.5f))
    }
}

@Composable
fun ConfirmDialog(title: String, message: String?, confirm: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = message?.let { { Text(it) } },
        confirmButton = { TextButton({ onConfirm(); onDismiss() }) { Text(confirm, color = Tokens.colors.danger) } },
        dismissButton = { TextButton(onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

// Material's DatePicker works in UTC millis; the app stores local dates.
fun LocalDate.toPickerMillis(): Long = atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
fun Long.fromPickerMillis(): LocalDate = Instant.ofEpochMilli(this).atZone(ZoneOffset.UTC).toLocalDate()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TramaDatePickerDialog(initial: LocalDate?, onPick: (LocalDate) -> Unit, onDismiss: () -> Unit) {
    val state = rememberDatePickerState(initialSelectedDateMillis = (initial ?: LocalDate.now()).toPickerMillis())
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton({ state.selectedDateMillis?.let { onPick(it.fromPickerMillis()) }; onDismiss() }) { Text(stringResource(R.string.common_ok)) }
        },
        dismissButton = { TextButton(onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    ) { DatePicker(state) }
}

// endregion

// region Funnel and cards

private data class Stage(val title: String, val value: Int, val icon: ImageVector, val tint: Color)

/** Funnel of an assignment's garments: planned → cut → produced → … → shipped. */
@Composable
fun ProductionFunnel(metrics: AssignmentMetrics, modifier: Modifier = Modifier) {
    val c = Tokens.colors
    val stages = listOf(
        Stage(stringResource(R.string.production_stage_planned), metrics.quantity, Icons.AutoMirrored.Filled.ListAlt, c.brand),
        Stage(stringResource(R.string.production_stage_cut), metrics.realCut, Icons.Filled.ContentCut, c.warning),
        Stage(stringResource(R.string.production_stage_produced), metrics.produced, Icons.Filled.PrecisionManufacturing, c.info),
        Stage(stringResource(R.string.production_stage_ironing), metrics.ironing, Icons.Filled.Iron, StageTints.ironing),
        Stage(stringResource(R.string.production_stage_packing), metrics.packing, Icons.Filled.Inventory2, StageTints.packing),
        Stage(stringResource(R.string.production_stage_warehouse), metrics.warehouse, Icons.Filled.Warehouse, StageTints.warehouse),
        Stage(stringResource(R.string.production_stage_shipped), metrics.shipped, Icons.AutoMirrored.Filled.Send, c.success),
    )
    val top = maxOf(metrics.quantity, metrics.realCut, 1).toDouble()
    val wide = isWideLayout()
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        stages.forEach { s ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(s.icon, null, tint = s.tint, modifier = Modifier.size(20.dp))
                Text(s.title, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.width(if (wide) 110.dp else 92.dp), maxLines = 1)
                val ratio = minOf(1.0, s.value / top)
                val animated by animateFloatAsState(ratio.toFloat(), spring(), label = "stage")
                Box(Modifier.weight(1f).height(12.dp).clip(Tokens.chipShape).background(s.tint.copy(alpha = 0.12f))) {
                    if (s.value > 0) {
                        Box(
                            Modifier.fillMaxHeight().fillMaxWidth(animated.coerceAtLeast(0.02f)).clip(Tokens.chipShape)
                                .background(Brush.horizontalGradient(listOf(s.tint.copy(alpha = 0.75f), s.tint))),
                        )
                    }
                }
                Text(
                    Fmt.int(s.value), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.widthIn(min = if (wide) 72.dp else 52.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End,
                )
            }
        }
    }
}

/** Compact card for an assignment (used by lists and the urgent screen). */
@Composable
fun AssignmentCard(graph: Graph, assignment: AssignmentEntity, modifier: Modifier = Modifier, showPlant: Boolean = true, onClick: (() -> Unit)? = null) {
    val app = LocalApp.current
    val order = graph.orderOf(assignment)
    val metrics = graph.metrics(assignment)
    val plant = graph.plantName(assignment)
    val c = Tokens.colors
    Column(
        modifier.clip(RoundedCornerShape(16.dp)).background(c.surface).border(1.dp, c.stroke, RoundedCornerShape(16.dp))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }.padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Swatch(graph.styleName(order), app.images.file(graph.style(order?.styleId)?.imageFile), Modifier.size(48.dp), corner = 12.dp)
            Column(Modifier.weight(1f)) {
                Text(graph.title(assignment), style = MaterialTheme.typography.titleMedium)
                Text(graph.clientName(order), style = MaterialTheme.typography.bodyMedium, color = c.secondary, maxLines = 1)
            }
            if (showPlant) Text(plant, style = MaterialTheme.typography.labelMedium, color = Tokens.accent(plant), maxLines = 1)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(
                pluralStringResource(R.plurals.production_garments_count, assignment.quantity.toPluralCount(), Fmt.int(assignment.quantity)),
                style = MaterialTheme.typography.bodySmall, color = c.secondary,
            )
            Text(stringResource(R.string.production_to_ship_count, Fmt.int(metrics.toShip)), style = MaterialTheme.typography.bodySmall, color = c.secondary)
        }
        Meter(metrics.shippingProgress, if (metrics.isComplete) c.success else c.brand)
    }
}

// endregion

// region Report editor

/** What the assignment screen (or the urgent list) wants to edit. */
sealed interface ReportEditorRequest {
    val assignmentId: String
    data class New(override val assignmentId: String, val kind: ReportKind) : ReportEditorRequest
    data class Edit(override val assignmentId: String, val reportId: String) : ReportEditorRequest
}

/** Clamp for plural selection (counts are Long in the database). */
fun Long.toPluralCount(): Int = coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()

private fun stampFormat() = DateTimeFormatter.ofPattern(if (Fmt.locale.language == "en") "MMM d, HH:mm" else "d MMM HH:mm", Fmt.locale)

@androidx.annotation.StringRes
private fun ReportKind.editTitleRes() = when (this) {
    ReportKind.Plant -> R.string.production_report_edit_plant
    ReportKind.Cut -> R.string.production_report_edit_cut
    ReportKind.Shipment -> R.string.production_report_edit_shipment
}

@androidx.annotation.StringRes
private fun ReportKind.savedRes() = when (this) {
    ReportKind.Plant -> R.string.production_report_saved_plant
    ReportKind.Cut -> R.string.production_report_saved_cut
    ReportKind.Shipment -> R.string.production_report_saved_shipment
}

/** Create or edit one of the three report kinds for an assignment, in a bottom sheet. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ReportEditorSheet(request: ReportEditorRequest, onDismiss: () -> Unit) {
    val graph by rememberGraph()
    val actions = rememberActions()
    val app = LocalApp.current
    val assignment = graph.assignment(request.assignmentId)
    val report: ReportEntity? = (request as? ReportEditorRequest.Edit)?.let { r -> graph.reports.firstOrNull { it.id == r.reportId } }
    val kind = when (request) {
        is ReportEditorRequest.New -> request.kind
        is ReportEditorRequest.Edit -> ReportKind.fromRaw(report?.kind)
    }
    if (assignment == null) {
        androidx.compose.runtime.LaunchedEffect(Unit) { onDismiss() }
        return
    }
    val metrics = graph.metrics(assignment)

    // Initial values: the edited report, or (for new ones) the latest snapshot so managers only adjust what changed.
    var operators by remember { mutableIntStateOf(report?.operators?.toInt() ?: metrics.operators) }
    var absences by remember { mutableIntStateOf(report?.absences?.toInt() ?: 0) }
    var produced by remember { mutableIntStateOf(report?.produced?.toInt() ?: metrics.produced) }
    var ironing by remember { mutableIntStateOf(report?.ironing?.toInt() ?: metrics.ironing) }
    var packing by remember { mutableIntStateOf(report?.packing?.toInt() ?: metrics.packing) }
    var warehouse by remember { mutableIntStateOf(report?.warehouse?.toInt() ?: metrics.warehouse) }
    var cutStatus by remember { mutableStateOf(report?.let { CutStatus.fromRaw(it.cutStatus) } ?: graph.cutStatus(assignment)) }
    var realQuantity by remember { mutableIntStateOf(report?.realQuantity?.toInt() ?: assignment.quantity.toInt()) }
    var shipmentNumber by remember {
        mutableStateOf(report?.shipmentNumber ?: "${graph.reportsOf(assignment).count { it.kind == ReportKind.Shipment.raw } + 1}")
    }
    var shippedQuantity by remember { mutableIntStateOf(report?.shippedQuantity?.toInt() ?: 0) }

    val canSave = when (kind) {
        ReportKind.Plant -> true
        ReportKind.Cut -> realQuantity >= 0
        ReportKind.Shipment -> shipmentNumber.isNotBlank() && shippedQuantity > 0
    }
    val title = stringResource(if (report == null) kind.titleRes else kind.editTitleRes())

    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = Tokens.colors.canvas) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).imePadding().navigationBarsPadding()
                .padding(horizontal = 24.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(title, style = MaterialTheme.typography.headlineSmall)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                IconTile(kind.icon, kind.tint(), 48.dp)
                Column {
                    Text(stringResource(R.string.production_cut_title, graph.title(assignment)), style = MaterialTheme.typography.titleMedium)
                    Text(
                        pluralStringResource(
                            R.plurals.production_report_header, assignment.quantity.toPluralCount(),
                            graph.plantName(assignment), Fmt.int(assignment.quantity), LocalDateTime.now().format(stampFormat()),
                        ),
                        style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary,
                    )
                }
            }
            when (kind) {
                ReportKind.Plant -> {
                    FormSection(stringResource(R.string.production_section_staff)) {
                        val operatorsLabel = stringResource(R.string.production_field_operators)
                        val absencesLabel = stringResource(R.string.production_field_absences)
                        FieldPair({ IntField(operators, { operators = it }, operatorsLabel, it) }, { IntField(absences, { absences = it }, absencesLabel, it) })
                    }
                    FormSection(stringResource(R.string.production_section_progress), footer = stringResource(R.string.production_progress_footer)) {
                        val producedLabel = stringResource(R.string.production_field_produced)
                        val ironingLabel = stringResource(R.string.production_stage_ironing)
                        val packingLabel = stringResource(R.string.production_stage_packing)
                        val warehouseLabel = stringResource(R.string.production_stage_warehouse)
                        FieldPair({ IntField(produced, { produced = it }, producedLabel, it) }, { IntField(ironing, { ironing = it }, ironingLabel, it) })
                        FieldPair({ IntField(packing, { packing = it }, packingLabel, it) }, { IntField(warehouse, { warehouse = it }, warehouseLabel, it) })
                    }
                }
                ReportKind.Cut -> {
                    FormSection(stringResource(R.string.production_section_cut_status)) {
                        CutStatus.entries.forEach { status ->
                            Row(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                                    .selectable(cutStatus == status, role = SemanticsRole.RadioButton) { cutStatus = status }
                                    .padding(vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                RadioButton(cutStatus == status, null)
                                Icon(status.icon, null, tint = status.tint(), modifier = Modifier.size(20.dp))
                                Text(stringResource(status.titleRes), style = MaterialTheme.typography.bodyLarge)
                            }
                        }
                    }
                    FormSection(
                        null,
                        footer = pluralStringResource(R.plurals.production_cut_footer, assignment.quantity.toPluralCount(), Fmt.int(assignment.quantity)),
                    ) { IntField(realQuantity, { realQuantity = it }, stringResource(R.string.production_field_real_cut)) }
                }
                ReportKind.Shipment -> {
                    val pending = metrics.toShip + (report?.shippedQuantity?.toInt() ?: 0)
                    FormSection(
                        stringResource(R.string.report_kind_shipment_short), footer = stringResource(R.string.production_shipment_pending, Fmt.int(pending)),
                        footerTint = if (shippedQuantity > pending) Tokens.colors.warning else null,
                    ) {
                        OutlinedTextField(
                            shipmentNumber, { shipmentNumber = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.production_field_shipment_number)) }, singleLine = true,
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters), shape = RoundedCornerShape(14.dp),
                        )
                        IntField(shippedQuantity, { shippedQuantity = it }, stringResource(R.string.production_field_shipped))
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onDismiss) { Text(stringResource(R.string.common_cancel)) }
                Spacer(Modifier.weight(1f))
                PrimaryButton(
                    stringResource(if (report == null) R.string.production_report_submit else R.string.common_save),
                    enabled = canSave,
                    onClick = {
                        val code = graph.title(assignment)
                        actions.run(
                            success = if (report == null) L10n.str(kind.savedRes(), code) else L10n.str(R.string.production_report_updated),
                            onDone = onDismiss,
                        ) {
                            val service = app.production()
                            when (kind) {
                                ReportKind.Plant -> service.savePlantReport(
                                    ProductionService.PlantReportInput(operators, absences, produced, ironing, packing, warehouse), assignment.id, report,
                                )
                                ReportKind.Cut -> service.saveCutReport(cutStatus, realQuantity, assignment.id, report)
                                ReportKind.Shipment -> service.saveShipmentReport(shipmentNumber, shippedQuantity, assignment.id, report)
                            }
                        }
                    },
                    modifier = Modifier.widthIn(min = 180.dp),
                )
            }
        }
    }
}

@Composable
private fun FormSection(title: String?, footer: String? = null, footerTint: Color? = null, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (title != null) Text(title, style = MaterialTheme.typography.labelLarge, color = Tokens.colors.secondary)
        content()
        if (footer != null) Text(footer, style = MaterialTheme.typography.bodySmall, color = footerTint ?: Tokens.colors.secondary)
    }
}

/** Two fields side by side on wide screens, stacked on phones. */
@Composable
private fun FieldPair(first: @Composable (Modifier) -> Unit, second: @Composable (Modifier) -> Unit) {
    if (isWideLayout()) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            first(Modifier.weight(1f)); second(Modifier.weight(1f))
        }
    } else {
        first(Modifier); second(Modifier)
    }
}

// endregion

@Composable
fun StatusDot(color: Color, size: Dp = 10.dp) = Box(Modifier.size(size).clip(CircleShape).background(color))

/** Plant pill with the plant's stable accent. */
@Composable
fun PlantPill(name: String) = Pill(name, Tokens.accent(name), Icons.Filled.Apartment)
