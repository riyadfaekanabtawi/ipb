package com.nevutech.trama.feature.clients

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.ToastCenter
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.WeaveTexture
import com.nevutech.trama.designsystem.tint
import java.text.Normalizer
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

// Building blocks shared by the catalog screens (port of ios CatalogViews.swift + FormKit pieces).

/** Case- and diacritic-insensitive search over several fields. */
fun catalogMatches(query: String, fields: List<String?>): Boolean {
    val q = query.trim()
    if (q.isEmpty()) return true
    return fold(fields.filterNotNull().joinToString(" ")).contains(fold(q))
}

private fun fold(text: String) =
    Normalizer.normalize(text, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()

/** Opens a mailto:, tel:, geo: or web link, reporting through the toasts when no app can handle it. */
fun openLink(context: Context, toasts: ToastCenter, uri: String) {
    val parsed = Uri.parse(uri)
    val intent = when (parsed.scheme) {
        "mailto" -> Intent(Intent.ACTION_SENDTO, parsed)
        "tel" -> Intent(Intent.ACTION_DIAL, parsed)
        else -> Intent(Intent.ACTION_VIEW, parsed)
    }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        toasts.show("No hay una app para abrir este enlace.", ToastCenter.Style.Info)
    }
}

/** Maps query for an address, or null when it is blank. */
fun mapsLink(address: String?): String? =
    address?.trim()?.takeIf { it.isNotEmpty() }?.let { "geo:0,0?q=" + Uri.encode(it) }

/**
 * Scrolling catalog page: a full-width header (title, search, actions) above an adaptive grid.
 * [content] adds grid items; use [fullSpan] for rows that should span every column.
 */
@Composable
fun CatalogGrid(
    title: String,
    search: String,
    onSearch: (String) -> Unit,
    searchPrompt: String,
    addTitle: String?,
    onAdd: () -> Unit,
    minCell: Dp = 320.dp,
    actions: @Composable RowScope.() -> Unit = {},
    content: LazyGridScope.() -> Unit,
) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minCell),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 24.dp, vertical = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(18.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        fullSpan {
            CatalogHeader(title, search, onSearch, searchPrompt, addTitle, onAdd, actions)
        }
        content()
    }
}

fun LazyGridScope.fullSpan(key: Any? = null, content: @Composable () -> Unit) =
    item(key = key, span = { GridItemSpan(maxLineSpan) }) { content() }

@Composable
fun CatalogHeader(
    title: String,
    search: String,
    onSearch: (String) -> Unit,
    searchPrompt: String,
    addTitle: String?,
    onAdd: () -> Unit,
    actions: @Composable RowScope.() -> Unit = {},
) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val wide = maxWidth > 760.dp
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(title, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.weight(1f))
                if (wide) SearchField(search, onSearch, searchPrompt, Modifier.widthIn(max = 360.dp))
                actions()
                if (addTitle != null) AddButton(addTitle, onAdd)
            }
            if (!wide) SearchField(search, onSearch, searchPrompt, Modifier.fillMaxWidth())
        }
    }
}

@Composable
fun AddButton(title: String, onClick: () -> Unit) {
    FilledTonalButton(onClick, contentPadding = PaddingValues(horizontal = 16.dp)) {
        Icon(Icons.Filled.Add, null, Modifier.size(18.dp))
        Spacer(Modifier.size(6.dp))
        Text(title, maxLines = 1)
    }
}

@Composable
fun SearchField(value: String, onChange: (String) -> Unit, prompt: String, modifier: Modifier = Modifier) {
    OutlinedTextField(
        value, onChange, modifier, singleLine = true, placeholder = { Text(prompt, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        leadingIcon = { Icon(Icons.Filled.Search, null, tint = Tokens.colors.secondary) },
        trailingIcon = if (value.isNotEmpty()) { { IconButton({ onChange("") }) { Icon(Icons.Filled.Close, "Borrar búsqueda") } } } else null,
        shape = Tokens.chipShape,
        colors = OutlinedTextFieldDefaults.colors(
            unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface,
        ),
    )
}

/** Search-aware empty state for grids. */
@Composable
fun NoResults(search: String) {
    com.nevutech.trama.designsystem.EmptyState(
        "Sin resultados para «${search.trim()}»", "Revisa la ortografía o prueba con otra búsqueda.", Icons.Filled.Search,
    )
}

/** Detail page: back button, title, trailing actions and a centered scrolling column. */
@Composable
fun DetailScaffold(
    title: String,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    val navigator = LocalNavigator.current
    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton({ navigator.back() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Atrás") }
            Text(title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            actions()
        }
        Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.TopCenter) {
            Column(
                Modifier.widthIn(max = 1400.dp).fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp).padding(bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp),
                content = content,
            )
        }
    }
}

/** "More" menu for detail toolbars. */
@Composable
fun OverflowMenu(items: @Composable ColumnScope.(close: () -> Unit) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton({ open = true }) { Icon(Icons.Filled.MoreVert, "Más opciones") }
        DropdownMenu(open, { open = false }) { items { open = false } }
    }
}

@Composable
fun MenuItem(text: String, icon: ImageVector, destructive: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val tint = if (destructive) Tokens.colors.danger else Tokens.colors.ink
    DropdownMenuItem(
        text = { Text(text, color = if (enabled) tint else tint.copy(alpha = 0.4f)) },
        leadingIcon = { Icon(icon, null, tint = if (enabled) tint else tint.copy(alpha = 0.4f)) },
        onClick = onClick, enabled = enabled,
    )
}

/** Brand hero header used at the top of catalog detail screens. */
@Composable
fun DetailHero(
    title: String,
    subtitle: String?,
    leading: @Composable () -> Unit,
    trailing: @Composable RowScope.() -> Unit = {},
) {
    val c = Tokens.colors
    BoxWithConstraints(
        Modifier.fillMaxWidth().clip(Tokens.cardShape)
            .background(Brush.linearGradient(listOf(c.brand, c.brandDeep))),
    ) {
        WeaveTexture(Modifier.matchParentSize(), spacing = 24f, ink = Color.White.copy(alpha = 0.06f))
        Box(Modifier.matchParentSize().background(Brush.radialGradient(listOf(c.thread.copy(alpha = 0.22f), Color.Transparent), radius = 900f, center = androidx.compose.ui.geometry.Offset(Float.POSITIVE_INFINITY, 0f))))
        val wide = maxWidth > 820.dp
        val titles: @Composable () -> Unit = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                if (subtitle != null) Text(subtitle, color = Color.White.copy(alpha = 0.8f), style = MaterialTheme.typography.bodyMedium, maxLines = 2)
            }
        }
        if (wide) {
            Row(Modifier.padding(28.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(22.dp)) {
                leading()
                Box(Modifier.weight(1f)) { titles() }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), content = trailing)
            }
        } else {
            Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    leading()
                    titles()
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), content = trailing)
            }
        }
    }
}

/** White-on-brand figure used inside [DetailHero]. */
@Composable
fun HeroStat(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(Tokens.smallRadius)).background(Color.White.copy(alpha = 0.12f)).padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(value, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        Text(label, color = Color.White.copy(alpha = 0.75f), style = MaterialTheme.typography.labelSmall)
    }
}

/** Compact icon + value + caption used on catalog cards. */
@Composable
fun CardStat(icon: ImageVector, value: String, label: String, tint: Color = Tokens.colors.brand) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.semantics(mergeDescendants = true) {}) {
        Box(Modifier.size(26.dp).clip(RoundedCornerShape(8.dp)).background(tint.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(15.dp))
        }
        Column {
            Text(value, style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(label, style = MaterialTheme.typography.labelSmall, color = Tokens.colors.secondary)
        }
    }
}

/** Row-style link used for order / assignment lists inside detail screens. */
@Composable
fun CatalogRowCard(onClick: () -> Unit, content: @Composable RowScope.() -> Unit) {
    Surface(
        onClick = onClick, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(Tokens.smallRadius),
        color = Tokens.colors.surface, border = androidx.compose.foundation.BorderStroke(1.dp, Tokens.colors.stroke),
    ) {
        Row(Modifier.padding(horizontal = 18.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            content()
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Tokens.colors.secondary.copy(alpha = 0.5f))
        }
    }
}

/** Right-aligned value/caption pair used in row cards. */
@Composable
fun RowFigure(value: String, label: String) {
    Column(horizontalAlignment = Alignment.End) {
        Text(value, style = MaterialTheme.typography.labelLarge, maxLines = 1)
        Text(label, style = MaterialTheme.typography.labelSmall, color = Tokens.colors.secondary)
    }
}

/** Title + subtitle + trailing slot for page sections. */
@Composable
fun SectionTitle(title: String, subtitle: String? = null, trailing: @Composable RowScope.() -> Unit = {}) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
        }
        trailing()
    }
}

/** Destructive confirmation, like iOS `confirmDelete`. */
@Composable
fun ConfirmDeleteDialog(title: String, message: String? = null, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = message?.let { { Text(it) } },
        confirmButton = { TextButton({ onDismiss(); onConfirm() }) { Text("Eliminar", color = Tokens.colors.danger) } },
        dismissButton = { TextButton(onDismiss) { Text("Cancelar") } },
    )
}

/** Modal form with Cancelar / title / Guardar, full screen on phones and a centered card on tablets. */
@Composable
fun FormSheet(
    title: String,
    onDismiss: () -> Unit,
    onSave: () -> Unit,
    canSave: Boolean,
    saveTitle: String = "Guardar",
    content: @Composable ColumnScope.() -> Unit,
) {
    Dialog(onDismiss, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        BoxWithConstraints(Modifier.fillMaxSize().imePadding(), contentAlignment = Alignment.Center) {
            val compact = maxWidth < 700.dp
            Surface(
                modifier = if (compact) Modifier.fillMaxSize() else Modifier.widthIn(max = 640.dp).fillMaxWidth().heightIn(max = maxHeight * 0.9f),
                shape = if (compact) RoundedCornerShape(0.dp) else Tokens.cardShape,
                color = Tokens.colors.canvas,
            ) {
                Column(if (compact) Modifier.statusBarsPadding() else Modifier) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onDismiss) { Text("Cancelar") }
                        Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                        TextButton(onSave, enabled = canSave) { Text(saveTitle, fontWeight = FontWeight.Bold) }
                    }
                    HorizontalDivider(color = Tokens.colors.stroke)
                    Column(
                        Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(22.dp),
                        content = content,
                    )
                }
            }
        }
    }
}

/** Grouped form section with header and optional footer. */
@Composable
fun FormSection(title: String?, footer: String? = null, footerColor: Color? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (title != null) Text(title.uppercase(), style = MaterialTheme.typography.labelMedium, color = Tokens.colors.secondary, modifier = Modifier.padding(start = 4.dp))
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(Tokens.smallRadius)).background(Tokens.colors.surface).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
        if (footer != null) Text(footer, style = MaterialTheme.typography.bodySmall, color = footerColor ?: Tokens.colors.secondary, modifier = Modifier.padding(horizontal = 4.dp))
    }
}

/** Dropdown picker over [options]. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> PickerField(
    label: String,
    options: List<T>,
    selected: T,
    text: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isError: Boolean = false,
) {
    var open by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(open, { if (enabled) open = it }, modifier) {
        OutlinedTextField(
            text(selected), {}, Modifier.fillMaxWidth().menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable, enabled),
            readOnly = true, enabled = enabled, singleLine = true, label = { Text(label) }, isError = isError,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(open) }, shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface),
        )
        ExposedDropdownMenu(open, { open = false }) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(text(option)) }, onClick = { onSelect(option); open = false })
            }
        }
    }
}

/** Segmented single choice (iOS `.pickerStyle(.segmented)`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> Segmented(options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit, modifier: Modifier = Modifier) {
    SingleChoiceSegmentedButtonRow(modifier) {
        options.forEachIndexed { i, option ->
            SegmentedButton(
                selected = option == selected, onClick = { onSelect(option) },
                shape = SegmentedButtonDefaults.itemShape(i, options.size),
            ) { Text(label(option), maxLines = 1, overflow = TextOverflow.Ellipsis) }
        }
    }
}

/** Password field with a reveal toggle. */
@Composable
fun SecureField(value: String, onChange: (String) -> Unit, label: String, isError: Boolean = false) {
    var reveal by remember { mutableStateOf(false) }
    OutlinedTextField(
        value, onChange, Modifier.fillMaxWidth(), label = { Text(label) }, singleLine = true, isError = isError,
        visualTransformation = if (reveal) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        trailingIcon = { IconButton({ reveal = !reveal }) { Icon(if (reveal) Icons.Filled.VisibilityOff else Icons.Filled.Visibility, if (reveal) "Ocultar contraseña" else "Mostrar contraseña") } },
        shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface),
    )
}

/** Tappable date row that opens a Material date picker. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateRow(label: String, date: LocalDate, onChange: (LocalDate) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { open = true }
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Text(Fmt.date(date), color = Tokens.colors.brand, fontWeight = FontWeight.SemiBold)
    }
    if (open) {
        // The picker works in UTC midnight millis.
        val state = rememberDatePickerState(initialSelectedDateMillis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton({
                    state.selectedDateMillis?.let { onChange(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }
                    open = false
                }) { Text("Listo") }
            },
            dismissButton = { TextButton({ open = false }) { Text("Cancelar") } },
        ) { DatePicker(state) }
    }
}

/** Card tap plus optional long press (context menu), with the ripple clipped to the card. */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
fun Modifier.cardClick(onClick: () -> Unit, onLongClick: (() -> Unit)? = null, shape: androidx.compose.ui.graphics.Shape = Tokens.cardShape): Modifier =
    clip(shape).combinedClickable(onClick = onClick, onLongClick = onLongClick, onLongClickLabel = onLongClick?.let { "Más opciones" })

/** Wraps [content] with a dropdown that [content] opens through the callback (long press menus). */
@Composable
fun WithContextMenu(menu: @Composable ColumnScope.(close: () -> Unit) -> Unit, content: @Composable (open: () -> Unit) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        content { open = true }
        DropdownMenu(open, { open = false }) { menu { open = false } }
    }
}

/** Catalog writes for the current screen. */
@Composable
fun rememberCatalog(): com.nevutech.trama.core.data.CatalogService {
    val app = LocalApp.current
    return remember(app) { com.nevutech.trama.core.data.CatalogService(app.db, app.images) }
}

/** Toasts from composables without reaching into the container each time. */
@Composable
fun rememberToasts(): ToastCenter = LocalApp.current.toasts

// Icons mirroring the iOS SF Symbols of each enum.

val com.nevutech.trama.core.domain.ProjectStatus.icon: ImageVector
    get() = when (this) {
        com.nevutech.trama.core.domain.ProjectStatus.Pending -> Icons.Filled.Schedule
        com.nevutech.trama.core.domain.ProjectStatus.Accepted -> Icons.Filled.CheckCircle
        com.nevutech.trama.core.domain.ProjectStatus.Declined -> Icons.Filled.Cancel
    }

/** Pending reads as "waiting" (warning) in pipeline KPIs, pills and columns, like iOS. */
@Composable
fun com.nevutech.trama.core.domain.ProjectStatus.displayTint(): Color =
    if (this == com.nevutech.trama.core.domain.ProjectStatus.Pending) Tokens.colors.warning else tint()

val com.nevutech.trama.core.domain.Role.icon: ImageVector
    get() = when (this) {
        com.nevutech.trama.core.domain.Role.Admin -> Icons.Filled.WorkspacePremium
        com.nevutech.trama.core.domain.Role.PlantManager -> Icons.Filled.Apartment
        com.nevutech.trama.core.domain.Role.CutManager -> Icons.Filled.ContentCut
        com.nevutech.trama.core.domain.Role.ShippingManager -> Icons.Filled.Inventory2
    }

val com.nevutech.trama.core.domain.CutStatus.icon: ImageVector
    get() = when (this) {
        com.nevutech.trama.core.domain.CutStatus.Waiting -> Icons.Filled.HourglassTop
        com.nevutech.trama.core.domain.CutStatus.OnTable -> Icons.Filled.ContentCut
        com.nevutech.trama.core.domain.CutStatus.Ready -> Icons.Filled.Verified
    }
