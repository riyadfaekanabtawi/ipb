package com.nevutech.trama.feature.dashboard

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.gestures.detectTapGestures
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.SectionHeader
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.capacityTint
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

// Shared chart building blocks (port of ios/Trama/DesignSystem/Components/ChartKit.swift).
// Drawn with Compose Canvas only; no chart library.

object MonthLabel {
    private val wide = DateTimeFormatter.ofPattern("MMMM yyyy", Fmt.locale)
    private val abbreviated = DateTimeFormatter.ofPattern("MMM", Fmt.locale)
    private val fullDay = DateTimeFormatter.ofPattern("EEEE, d 'de' MMMM 'de' yyyy", Fmt.locale)

    /** "Octubre 2026" */
    fun long(month: YearMonth): String = month.atDay(1).format(wide).replace(" de ", " ").capitalizedFirst()

    /** "oct" */
    fun short(month: YearMonth): String = month.atDay(1).format(abbreviated).replace(".", "")

    /** "Sábado, 24 de octubre de 2026" */
    fun fullDay(date: LocalDate): String = date.format(fullDay).capitalizedFirst()
}

fun String.capitalizedFirst(): String = replaceFirstChar { it.titlecase(Fmt.locale) }

/** Card with a section header and arbitrary chart content. */
@Composable
fun ChartCard(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
    trailing: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    TramaCard(modifier.fillMaxWidth()) {
        SectionHeader(title, subtitle, trailing)
        Spacer(Modifier.height(4.dp))
        content()
    }
}

/** "‹ Octubre 2026 ›" stepper over calendar months. */
@Composable
fun MonthStepper(month: YearMonth, onChange: (YearMonth) -> Unit, modifier: Modifier = Modifier) {
    val haptics = LocalHapticFeedback.current
    fun set(value: YearMonth) {
        onChange(value)
        haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
    }
    Row(
        modifier.clip(CircleShape).background(Tokens.colors.ink.copy(alpha = 0.05f)).padding(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StepButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Mes anterior") { set(month.minusMonths(1)) }
        Text(
            MonthLabel.long(month),
            style = MaterialTheme.typography.labelLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .widthIn(min = 132.dp)
                .pointerInput(month) { detectTapGestures(onDoubleTap = { set(YearMonth.now()) }) }
                .semantics { contentDescription = "Mes seleccionado: ${MonthLabel.long(month)}. Toca dos veces para volver al mes actual" },
        )
        StepButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Mes siguiente") { set(month.plusMonths(1)) }
    }
}

@Composable
private fun StepButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    IconButton(onClick, Modifier.size(36.dp)) {
        Box(Modifier.size(30.dp).clip(CircleShape).background(Tokens.colors.surface), contentAlignment = Alignment.Center) {
            Icon(icon, label, tint = Tokens.colors.brand, modifier = Modifier.size(20.dp))
        }
    }
}

/** Colored dot + title + value, for chart legends. */
@Composable
fun LegendRow(color: Color, title: String, value: String, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(color))
        Text(title, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
    }
}

/** Small inline legend (dot + name) for chart headers. */
@Composable
fun LegendChip(color: Color, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        Text(title, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Compact empty state for cards. */
@Composable
fun CardEmptyState(title: String, icon: ImageVector, message: String? = null) {
    Column(
        Modifier.fillMaxWidth().heightIn(min = 120.dp).padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
    ) {
        Icon(icon, null, tint = Tokens.colors.brand.copy(alpha = 0.6f), modifier = Modifier.size(28.dp))
        Text(title, style = MaterialTheme.typography.titleSmall)
        if (message != null) Text(message, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, textAlign = TextAlign.Center)
    }
}

// Bar chart (horizontal, used vs max)

data class BarPoint(val label: String, val value: Double, val max: Double) {
    val ratio: Double get() = if (max > 0) value / max else 0.0
}

/** One horizontal capsule per point: track = max, fill = value, tinted by utilization, % inside. */
@Composable
fun CapacityBarChart(points: List<BarPoint>, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().semantics(mergeDescendants = true) {
            contentDescription = points.joinToString(", ") { "${it.label}: ${Fmt.percent(it.ratio)} usado" }
        },
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        points.forEach { point ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    point.label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.width(120.dp),
                )
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    CapsuleBar(point.ratio, capacityTint(point.ratio.toFloat()))
                    Text(
                        "${Fmt.money(point.value, compact = true)} de ${Fmt.money(point.max, compact = true)}",
                        style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary,
                    )
                }
            }
        }
    }
}

@Composable
private fun CapsuleBar(ratio: Double, tint: Color, height: Dp = 26.dp) {
    val animated by animateFloatAsState(ratio.toFloat().coerceIn(0f, 1f), spring(), label = "bar")
    val track = Tokens.colors.ink.copy(alpha = 0.07f)
    val measurer = rememberTextMeasurer()
    val label = Fmt.percent(ratio)
    val labelStyle = TextStyle(color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    val outsideStyle = labelStyle.copy(color = Tokens.colors.secondary)
    Canvas(Modifier.fillMaxWidth().height(height)) {
        val r = CornerRadius(size.height / 2)
        drawRoundRect(track, cornerRadius = r)
        if (ratio <= 0) return@Canvas
        val w = (size.width * animated).coerceAtLeast(size.height)
        drawRoundRect(tint, size = Size(w, size.height), cornerRadius = r)
        val text = measurer.measure(label, labelStyle)
        val inside = text.size.width + 16 < w
        val x = if (inside) w - text.size.width - 8 else w + 6
        if (x + text.size.width <= size.width) {
            drawText(measurer, label, Offset(x, (size.height - text.size.height) / 2), if (inside) labelStyle else outsideStyle)
        }
    }
}

// Stacked bars (12 months × series)

data class StackSeries(val name: String, val color: Color, val values: List<Double>)

/**
 * Vertical stacked bars, one column per entry of [labels]. Tapping a column calls [onSelect];
 * the [selected] column is drawn at full opacity, the rest dimmed.
 */
@Composable
fun StackedBarChart(
    series: List<StackSeries>,
    labels: List<String>,
    selected: Int?,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    height: Dp = 240.dp,
    valueLabel: (Double) -> String = { Fmt.money(it, compact = true) },
) {
    val count = labels.size
    val totals = (0 until count).map { i -> series.sumOf { it.values.getOrElse(i) { 0.0 } } }
    val top = niceCeiling(totals.maxOrNull() ?: 0.0)
    val measurer = rememberTextMeasurer()
    val axisStyle = TextStyle(color = Tokens.colors.secondary, fontSize = 11.sp)
    val grid = Tokens.colors.ink.copy(alpha = 0.08f)
    val haptics = LocalHapticFeedback.current
    val gutter = 56.dp

    Column(modifier.fillMaxWidth()) {
        Canvas(
            Modifier.fillMaxWidth().height(height)
                .pointerInput(count) {
                    detectTapGestures { pos ->
                        val left = gutter.toPx()
                        if (pos.x < left || count == 0) return@detectTapGestures
                        val index = ((pos.x - left) / ((size.width - left) / count)).toInt().coerceIn(0, count - 1)
                        haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
                        onSelect(index)
                    }
                },
        ) {
            val left = gutter.toPx()
            val plotW = size.width - left
            val plotH = size.height
            // Grid + y labels
            val steps = 4
            for (s in 0..steps) {
                val y = plotH - plotH * s / steps
                drawLine(grid, Offset(left, y), Offset(size.width, y), strokeWidth = 1.dp.toPx())
                val text = measurer.measure(valueLabel(top * s / steps), axisStyle)
                drawText(text, topLeft = Offset(left - text.size.width - 8.dp.toPx(), (y - text.size.height / 2).coerceIn(0f, plotH - text.size.height)))
            }
            if (top <= 0 || count == 0) return@Canvas
            val slot = plotW / count
            val barW = slot * 0.62f
            for (i in 0 until count) {
                val alpha = if (selected == null || selected == i) 1f else 0.55f
                var base = plotH
                series.forEach { s ->
                    val v = s.values.getOrElse(i) { 0.0 }
                    if (v <= 0) return@forEach
                    val h = (v / top * plotH).toFloat()
                    drawRoundRect(
                        s.color.copy(alpha = alpha),
                        topLeft = Offset(left + slot * i + (slot - barW) / 2, base - h),
                        size = Size(barW, (h - 1.5f).coerceAtLeast(1f)),
                        cornerRadius = CornerRadius(4.dp.toPx()),
                    )
                    base -= h
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(start = gutter, top = 6.dp)) {
            labels.forEachIndexed { i, label ->
                Text(
                    label, style = MaterialTheme.typography.labelSmall, textAlign = TextAlign.Center, maxLines = 1,
                    color = if (i == selected) Tokens.colors.brand else Tokens.colors.secondary,
                    fontWeight = if (i == selected) FontWeight.Bold else FontWeight.Medium,
                    modifier = Modifier.weight(1f)
                        .clickable(role = Role.Button, onClickLabel = "Seleccionar $label") { onSelect(i) },
                )
            }
        }
    }
}

/** Rounds up to 1, 2, 2.5 or 5 × 10ⁿ so axis labels stay readable. */
fun niceCeiling(value: Double): Double {
    if (value <= 0) return 0.0
    val magnitude = Math.pow(10.0, Math.floor(Math.log10(value)))
    val f = value / magnitude
    val nice = listOf(1.0, 2.0, 2.5, 5.0, 10.0).first { f <= it }
    return nice * magnitude
}

// Donut

data class DonutSlice(val label: String, val value: Int, val color: Color)

/** Ring of slices with small gaps and a centered total. */
@Composable
fun DonutChart(slices: List<DonutSlice>, centerValue: String, centerCaption: String, modifier: Modifier = Modifier, size: Dp = 190.dp) {
    val total = slices.sumOf { it.value }.coerceAtLeast(1)
    val track = Tokens.colors.ink.copy(alpha = 0.06f)
    BoxWithConstraints(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(Modifier.size(size), contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(size)) {
                val stroke = this.size.minDimension * 0.18f
                val inset = stroke / 2
                val arcSize = Size(this.size.width - stroke, this.size.height - stroke)
                drawArc(track, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                val nonEmpty = slices.count { it.value > 0 }
                val gap = if (nonEmpty > 1) 2.5f else 0f
                var start = -90f
                slices.forEach { slice ->
                    if (slice.value <= 0) return@forEach
                    val sweep = 360f * slice.value / total
                    drawArc(slice.color, start + gap / 2, (sweep - gap).coerceAtLeast(0.5f), false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                    start += sweep
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(centerValue, fontSize = 30.sp, fontWeight = FontWeight.Bold)
                Text(centerCaption, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
            }
        }
    }
}

/** Grid that fits as many [minWidth] columns as the width allows (SwiftUI `.adaptive(minimum:)`). */
@Composable
fun AdaptiveGrid(
    itemCount: Int,
    minWidth: Dp,
    modifier: Modifier = Modifier,
    spacing: Dp = 16.dp,
    item: @Composable (index: Int, modifier: Modifier) -> Unit,
) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val columns = ((maxWidth + spacing) / (minWidth + spacing)).toInt().coerceIn(1, itemCount.coerceAtLeast(1))
        Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
            (0 until itemCount).chunked(columns).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(spacing)) {
                    row.forEach { index -> item(index, Modifier.weight(1f)) }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}
