package com.nevutech.trama.feature.styles

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.OpenInFull
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.ImageEdit
import com.nevutech.trama.core.data.StyleEntity
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.feature.clients.CatalogGrid
import com.nevutech.trama.feature.clients.ConfirmDeleteDialog
import com.nevutech.trama.feature.clients.FormSection
import com.nevutech.trama.feature.clients.FormSheet
import com.nevutech.trama.feature.clients.MenuItem
import com.nevutech.trama.feature.clients.NoResults
import com.nevutech.trama.feature.clients.WithContextMenu
import com.nevutech.trama.feature.clients.catalogMatches
import com.nevutech.trama.feature.clients.fullSpan
import com.nevutech.trama.feature.clients.rememberCatalog
import com.nevutech.trama.feature.clients.rememberToasts

enum class StyleSort(@StringRes val titleRes: Int) { Name(R.string.common_name), Orders(R.string.styles_sort_orders), Recent(R.string.styles_sort_recent) }

/** Sheet target: a new style (null) or an existing one. */
data class StyleEditorTarget(val style: StyleEntity?)

@Composable
fun StylesScreen() {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    val catalog = rememberCatalog()
    var search by rememberSaveable { mutableStateOf("") }
    var sort by rememberSaveable { mutableStateOf(StyleSort.Name) }
    var editor by remember { mutableStateOf<StyleEditorTarget?>(null) }
    var pendingDelete by remember { mutableStateOf<StyleEntity?>(null) }
    var zoomed by remember { mutableStateOf<StyleEntity?>(null) }

    val styles = graph.styles
    val matches = styles.filter { s -> catalogMatches(search, listOf(s.name) + graph.plantDistribution(s).map { it.first.name }) }
    val visible = when (sort) {
        StyleSort.Name -> matches
        StyleSort.Orders -> matches.sortedByDescending { graph.ordersOf(it).size }
        StyleSort.Recent -> matches.sortedByDescending { it.createdAt }
    }

    TramaScreen {
        CatalogGrid(
            stringResource(R.string.section_styles), search, { search = it }, stringResource(R.string.styles_search_hint), stringResource(R.string.styles_new), { editor = StyleEditorTarget(null) },
            minCell = 200.dp, actions = { SortMenu(sort) { sort = it } },
        ) {
            when {
                styles.isEmpty() -> fullSpan {
                    EmptyState(stringResource(R.string.styles_empty_title), stringResource(R.string.styles_empty_message), Icons.Filled.Checkroom) {
                        PrimaryButton(stringResource(R.string.styles_new), { editor = StyleEditorTarget(null) }, icon = Icons.Filled.PhotoCamera)
                    }
                }
                visible.isEmpty() -> fullSpan { NoResults(search) }
                else -> items(visible.size, key = { visible[it].id }) { i ->
                    val style = visible[i]
                    WithContextMenu(menu = { close ->
                        MenuItem(stringResource(R.string.styles_view_image), Icons.Filled.OpenInFull) { close(); zoomed = style }
                        MenuItem(stringResource(R.string.common_edit), Icons.Filled.Edit) { close(); editor = StyleEditorTarget(style) }
                        HorizontalDivider()
                        MenuItem(stringResource(R.string.common_delete), Icons.Filled.Delete, destructive = true) { close(); pendingDelete = style }
                    }) { open ->
                        StyleCard(graph, style, onClick = { navigator.openStyle(style.id) }, onLongClick = open, zoom = { zoomed = style })
                    }
                }
            }
        }
    }

    editor?.let { StyleEditorSheet(it.style) { editor = null } }
    zoomed?.let { style -> ZoomableImageViewer(app.images.file(style.imageFile), style.name) { zoomed = null } }
    pendingDelete?.let { style ->
        ConfirmDeleteDialog(
            stringResource(R.string.styles_delete_title, style.name), stringResource(R.string.styles_delete_message),
            onConfirm = { actions.run(success = L10n.str(R.string.styles_deleted, style.name)) { catalog.deleteStyle(style) } },
            onDismiss = { pendingDelete = null },
        )
    }
}

@Composable
private fun SortMenu(sort: StyleSort, onChange: (StyleSort) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton({ open = true }) { Icon(Icons.AutoMirrored.Filled.Sort, stringResource(R.string.styles_sort_label, stringResource(sort.titleRes))) }
        DropdownMenu(open, { open = false }) {
            StyleSort.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(stringResource(option.titleRes)) }, onClick = { onChange(option); open = false },
                    leadingIcon = { if (option == sort) Icon(Icons.Filled.Check, null) else Spacer(Modifier.size(24.dp)) },
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class, androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun StyleCard(graph: Graph, style: StyleEntity, onClick: () -> Unit, onLongClick: () -> Unit, zoom: () -> Unit) {
    val images = LocalApp.current.images
    val file = images.file(style.imageFile)
    val distribution = graph.plantDistribution(style)
    val orderCount = graph.ordersOf(style).size
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    // Gentle press-down for the image cards.
    val scale by androidx.compose.animation.core.animateFloatAsState(if (pressed) 0.97f else 1f, label = "press")
    val moreOptions = stringResource(R.string.common_more_options)

    Column(
        Modifier.scale(scale).fillMaxWidth().clip(Tokens.cardShape).background(Tokens.colors.surface)
            .border(1.dp, Tokens.colors.stroke, Tokens.cardShape)
            .combinedClickable(interactionSource = interaction, indication = androidx.compose.foundation.LocalIndication.current, onClick = onClick, onLongClick = onLongClick, onLongClickLabel = moreOptions),
    ) {
        Box(Modifier.fillMaxWidth().height(240.dp)) {
            Swatch(style.name, file, Modifier.fillMaxSize(), corner = 0.dp)
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.5f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.55f))))
            Row(Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f)) {
                    Text(style.name, color = Color.White, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Text(pluralStringResource(R.plurals.styles_cut_count, orderCount, Fmt.int(orderCount)), color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.labelMedium)
                }
                if (file != null) {
                    IconButton(zoom, Modifier.size(34.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.35f))) {
                        Icon(Icons.Filled.OpenInFull, stringResource(R.string.styles_view_image_of, style.name), tint = Color.White, modifier = Modifier.size(16.dp))
                    }
                }
            }
        }
        Box(Modifier.fillMaxWidth().heightIn(min = 30.dp).padding(14.dp)) {
            if (distribution.isEmpty()) {
                Text(stringResource(R.string.styles_no_plants), style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary.copy(alpha = 0.6f))
            } else {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    distribution.forEach { (plant, count) -> Pill("${plant.name}: $count", Tokens.accent(plant.name), Icons.Filled.Apartment) }
                }
            }
        }
    }
}

@Composable
fun StyleEditorSheet(style: StyleEntity?, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val catalog = rememberCatalog()
    val actions = rememberActions()
    val toasts = rememberToasts()
    var name by remember { mutableStateOf(style?.name ?: "") }
    var image by remember { mutableStateOf<ImageEdit>(ImageEdit.Keep) }
    val current = app.images.file(style?.imageFile)
    val title = name.ifBlank { stringResource(R.string.common_style) }

    FormSheet(
        stringResource(if (style == null) R.string.styles_new else R.string.styles_edit), onDismiss,
        onSave = {
            actions.run(onDone = onDismiss) {
                val saved = catalog.saveStyle(style, name, image)
                toasts.show(if (style == null) L10n.str(R.string.styles_created, saved.name) else L10n.str(R.string.styles_updated))
            }
        },
        canSave = name.isNotBlank(),
    ) {
        PhotoPreview(title, current, image, Modifier.fillMaxWidth().height(260.dp), corner = Tokens.smallRadius)
        FormSection(stringResource(R.string.common_style)) { TramaField(name, { name = it }, stringResource(R.string.styles_name_hint)) }
        FormSection(stringResource(R.string.photo_section)) { PhotoField(title, current, image) { image = it } }
    }
}
