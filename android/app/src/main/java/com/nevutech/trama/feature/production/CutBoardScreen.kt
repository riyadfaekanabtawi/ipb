package com.nevutech.trama.feature.production

import android.content.ClipData
import android.content.ClipDescription
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.draganddrop.dragAndDropSource
import androidx.compose.foundation.draganddrop.dragAndDropTarget
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draganddrop.DragAndDropEvent
import androidx.compose.ui.draganddrop.DragAndDropTarget
import androidx.compose.ui.draganddrop.DragAndDropTransferData
import androidx.compose.ui.draganddrop.mimeTypes
import androidx.compose.ui.draganddrop.toAndroidDragEvent
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.ToastCenter
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.tint

private const val DRAG_LABEL = "trama/assignment"

/**
 * Kanban of assignments by cutting status. Cards are long-pressed and dragged between columns;
 * each move updates the assignment's single cut report. A card menu offers the same moves.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CutBoardScreen() {
    val graph by rememberGraph()
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    val user by app.session.user.collectAsState()
    val role = rememberRole()
    val canMove = role.canEdit(ReportKind.Cut)
    val wide = isWideLayout()

    var query by rememberSaveable { mutableStateOf("") }
    var plantId by rememberSaveable { mutableStateOf<String?>(null) }
    var hideShipped by rememberSaveable { mutableStateOf(true) }
    var targeted by remember { mutableStateOf<CutStatus?>(null) }

    val q = query.trim().lowercase()
    val visible = graph.visibleAssignments(user)
        .filter { a -> (plantId == null || a.plantId == plantId) && (q.isEmpty() || graph.searchText(a).contains(q)) && (!hideShipped || !graph.metrics(a).isComplete) }
        .sortedBy { it.scheduledDate ?: Long.MAX_VALUE }
    val grouped = visible.groupBy { graph.cutStatus(it) }

    val move: (AssignmentEntity, CutStatus) -> Unit = { a, status ->
        if (graph.cutStatus(a) != status) {
            actions.run(success = L10n.str(R.string.board_moved, graph.title(a), status.title)) { app.production().move(a.id, status) }
        }
    }

    TramaScreen {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.section_board), showTitle = wide)
            Column(Modifier.padding(horizontal = if (wide) 24.dp else 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SearchBox(query, { query = it }, stringResource(R.string.board_search_placeholder))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val plants = graph.plants.sortedBy { it.name.lowercase() }
                    FilterMenuChip(
                        graph.plant(plantId)?.name ?: stringResource(R.string.board_all_plants), Icons.Filled.Apartment, plantId != null,
                        listOf<Pair<String, () -> Unit>>(stringResource(R.string.board_all_plants) to { plantId = null }) + plants.map { p -> p.name to { plantId = p.id } },
                    )
                    FilterChipButton(stringResource(R.string.board_hide_shipped), Icons.Filled.VisibilityOff, hideShipped, { hideShipped = !hideShipped })
                }
            }
            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
                val padding = if (wide) 24.dp else 16.dp
                val spacing = 18.dp
                // Three columns fill the width; below 260dp each the board scrolls sideways.
                val columnWidth = maxOf(260.dp, (maxWidth - padding * 2 - spacing * 2) / 3)
                Row(
                    Modifier.fillMaxSize().horizontalScroll(rememberScrollState()).padding(padding),
                    horizontalArrangement = Arrangement.spacedBy(spacing),
                ) {
                    CutStatus.entries.forEach { status ->
                        BoardColumn(
                            graph, status, grouped[status].orEmpty(), columnWidth, canMove, targeted == status,
                            onTargeted = { on -> targeted = if (on) status else if (targeted == status) null else targeted },
                            onDropId = { id ->
                                if (!canMove) {
                                    app.toasts.show(L10n.str(R.string.board_move_not_allowed), ToastCenter.Style.Info)
                                } else {
                                    graph.assignment(id)?.let { move(it, status) }
                                }
                            },
                            onOpen = { navigator.openAssignment(it.id) },
                            onMove = move,
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BoardColumn(
    graph: Graph,
    status: CutStatus,
    items: List<AssignmentEntity>,
    width: androidx.compose.ui.unit.Dp,
    canMove: Boolean,
    isTargeted: Boolean,
    onTargeted: (Boolean) -> Unit,
    onDropId: (String) -> Unit,
    onOpen: (AssignmentEntity) -> Unit,
    onMove: (AssignmentEntity, CutStatus) -> Unit,
) {
    val tint = status.tint()
    val background by animateColorAsState(tint.copy(alpha = if (isTargeted) 0.16f else 0.06f), label = "column")
    val border by animateColorAsState(tint.copy(alpha = if (isTargeted) 0.8f else 0.15f), label = "border")
    val shape = Tokens.cardShape
    val currentOnDrop by rememberUpdatedState(onDropId)
    val currentOnTargeted by rememberUpdatedState(onTargeted)
    val target = remember {
        object : DragAndDropTarget {
            override fun onDrop(event: DragAndDropEvent): Boolean {
                currentOnTargeted(false)
                val id = event.toAndroidDragEvent().clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString() ?: return false
                currentOnDrop(id)
                return true
            }
            override fun onEntered(event: DragAndDropEvent) = currentOnTargeted(true)
            override fun onExited(event: DragAndDropEvent) = currentOnTargeted(false)
            override fun onEnded(event: DragAndDropEvent) = currentOnTargeted(false)
        }
    }
    val garments = items.sumOf { it.quantity }

    Column(
        Modifier.width(width).fillMaxHeight().background(background, shape).border(if (isTargeted) 2.dp else 1.dp, border, shape)
            .dragAndDropTarget(shouldStartDragAndDrop = { it.mimeTypes().contains(ClipDescription.MIMETYPE_TEXT_PLAIN) }, target = target)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                Modifier.size(34.dp).background(Brush.verticalGradient(listOf(tint, tint.copy(alpha = 0.8f))), RoundedCornerShape(10.dp)),
                contentAlignment = Alignment.Center,
            ) { Icon(status.icon, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
            Column {
                Text(stringResource(status.titleRes), style = MaterialTheme.typography.titleMedium)
                Text(
                    pluralStringResource(R.plurals.board_column_summary, items.size, items.size, Fmt.int(garments)),
                    style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary,
                )
            }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (items.isEmpty()) {
                Box(
                    Modifier.fillMaxWidth().height(120.dp).drawBehind {
                        drawRoundRect(
                            tint.copy(alpha = 0.4f), cornerRadius = CornerRadius(16.dp.toPx()),
                            style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(18f, 18f))),
                        )
                    },
                    contentAlignment = Alignment.Center,
                ) { Text(stringResource(if (canMove) R.string.board_drop_here else R.string.board_no_cuts), color = Tokens.colors.secondary) }
            }
            items.forEach { a ->
                BoardCard(graph, a, status, canMove, onOpen = { onOpen(a) }, onMove = { onMove(a, it) })
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BoardCard(graph: Graph, a: AssignmentEntity, status: CutStatus, canMove: Boolean, onOpen: () -> Unit, onMove: (CutStatus) -> Unit) {
    val app = LocalApp.current
    val c = Tokens.colors
    val order = graph.orderOf(a)
    val metrics = graph.metrics(a)
    var menu by remember { mutableStateOf(false) }
    val targets = CutStatus.entries.filter { it != status }
    val dragModifier = if (canMove) {
        Modifier.dragAndDropSource { _ ->
            DragAndDropTransferData(ClipData.newPlainText(DRAG_LABEL, a.id), localState = a.id)
        }
    } else Modifier

    val moveLabels = targets.associateWith { stringResource(R.string.board_move_to, stringResource(it.titleRes)) }
    Surface(
        onClick = onOpen,
        modifier = Modifier.fillMaxWidth().then(dragModifier).semantics {
            if (canMove) customActions = targets.map { t -> CustomAccessibilityAction(moveLabels.getValue(t)) { onMove(t); true } }
        },
        shape = RoundedCornerShape(16.dp), color = c.surface, border = BorderStroke(1.dp, c.stroke), shadowElevation = 2.dp,
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    Text(graph.title(a), style = MaterialTheme.typography.titleMedium)
                    Text(graph.clientName(order), style = MaterialTheme.typography.bodyMedium, color = c.secondary, maxLines = 1)
                }
                Swatch(graph.styleName(order), app.images.file(graph.style(order?.styleId)?.imageFile), Modifier.size(40.dp), corner = 10.dp)
                if (canMove) {
                    Box {
                        IconButton({ menu = true }, Modifier.size(36.dp)) { Icon(Icons.Filled.MoreVert, stringResource(R.string.board_move_cut, graph.title(a)), tint = c.secondary) }
                        DropdownMenu(menu, { menu = false }) {
                            targets.forEach { t ->
                                DropdownMenuItem(
                                    text = { Text(moveLabels.getValue(t)) }, leadingIcon = { Icon(t.icon, null, tint = t.tint()) },
                                    onClick = { menu = false; onMove(t) },
                                )
                            }
                        }
                    }
                }
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                PlantPill(graph.plantName(a))
                DaysLeftBadge(graph.clientDate(a))
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.AutoMirrored.Filled.ListAlt, null, tint = c.secondary, modifier = Modifier.size(14.dp))
                Text(" ${Fmt.int(a.quantity)}", style = MaterialTheme.typography.bodySmall, color = c.secondary, modifier = Modifier.weight(1f))
                Icon(Icons.Filled.ContentCut, null, tint = c.secondary, modifier = Modifier.size(14.dp))
                Text(
                    " ${if (metrics.realCut > 0) Fmt.int(metrics.realCut) else "—"}", style = MaterialTheme.typography.bodySmall,
                    color = if (metrics.realCut > 0) c.ink else c.secondary, fontWeight = if (metrics.realCut > 0) FontWeight.SemiBold else null,
                )
            }
        }
    }
}
