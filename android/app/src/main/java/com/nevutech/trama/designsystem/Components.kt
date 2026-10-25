package com.nevutech.trama.designsystem

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.outlined.Checkroom
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.nevutech.trama.core.domain.Fmt
import java.io.File

/** Rounded raised card used across the app. */
@Composable
fun TramaCard(
    modifier: Modifier = Modifier,
    padding: Dp = 20.dp,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val c = Tokens.colors
    val base = modifier
        .clip(Tokens.cardShape)
        .background(c.surface)
        .border(1.dp, c.stroke, Tokens.cardShape)
    Column(
        (if (onClick != null) base.clickable(onClick = onClick) else base).padding(padding),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

/** Screen container: linen canvas with the woven texture. */
@Composable
fun TramaScreen(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.fillMaxSize().background(Tokens.colors.canvas)) {
        WeaveTexture()
        content()
    }
}

@Composable
fun SectionHeader(title: String, subtitle: String? = null, trailing: @Composable RowScope.() -> Unit = {}) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
        }
        trailing()
    }
}

/** Small capsule tag with optional icon and tint. */
@Composable
fun Pill(text: String, tint: Color, icon: ImageVector? = null, modifier: Modifier = Modifier) {
    Row(
        modifier
            .clip(Tokens.chipShape)
            .background(tint.copy(alpha = 0.14f))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        if (icon != null) Icon(icon, null, tint = tint, modifier = Modifier.size(14.dp))
        Text(text, color = tint, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Label/value row for detail cards. */
@Composable
fun InfoRow(label: String, value: String, icon: ImageVector? = null) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (icon != null) Icon(icon, null, tint = Tokens.colors.brand, modifier = Modifier.size(20.dp))
        Text(label, color = Tokens.colors.secondary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}

/** Big-number KPI tile. */
@Composable
fun KpiTile(
    title: String,
    value: String,
    icon: ImageVector,
    tint: Color = Tokens.colors.brand,
    footnote: String? = null,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
) {
    TramaCard(modifier, padding = 18.dp, onClick = onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(tint.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center,
            ) { Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp)) }
            Spacer(Modifier.weight(1f))
            if (onClick != null) Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = Tokens.colors.secondary.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
        }
        Column {
            AnimatedContent(value, label = "kpi") { v ->
                Text(v, fontSize = 30.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            }
            Text(title, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, fontWeight = FontWeight.Medium)
            if (footnote != null) Text(footnote, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary.copy(alpha = 0.7f))
        }
    }
}

/** Capacity bar with threshold coloring and an optional preview of what an assignment would add. */
@Composable
fun CapacityBar(used: Double, max: Double, modifier: Modifier = Modifier, preview: Double = 0.0, height: Dp = 12.dp) {
    val ratio = if (max > 0) (used / max).toFloat() else 0f
    val previewRatio = if (max > 0) ((used + preview) / max).toFloat() else 0f
    val animated by animateFloatAsState(ratio.coerceIn(0f, 1f), spring(), label = "cap")
    val animatedPreview by animateFloatAsState(previewRatio.coerceIn(0f, 1f), spring(), label = "preview")
    val track = Tokens.colors.ink.copy(alpha = 0.08f)
    val main = capacityTint(ratio)
    val ghost = capacityTint(previewRatio).copy(alpha = 0.35f)
    Canvas(
        modifier.fillMaxWidth().height(height).semantics { contentDescription = "Capacidad usada ${Fmt.percent(ratio.toDouble())}" },
    ) {
        val r = size.height / 2
        drawRoundRect(track, cornerRadius = androidx.compose.ui.geometry.CornerRadius(r))
        if (preview > 0) drawRoundRect(ghost, size = size.copy(width = size.width * animatedPreview), cornerRadius = androidx.compose.ui.geometry.CornerRadius(r))
        drawRoundRect(main, size = size.copy(width = size.width * animated), cornerRadius = androidx.compose.ui.geometry.CornerRadius(r))
    }
}

@Composable
fun capacityTint(ratio: Float): Color = when {
    ratio < 0.7f -> Tokens.colors.success
    ratio < 0.95f -> Tokens.colors.warning
    else -> Tokens.colors.danger
}

@Composable
fun ProgressRing(progress: Double, modifier: Modifier = Modifier, tint: Color = Tokens.colors.brand, stroke: Dp = 8.dp) {
    val animated by animateFloatAsState(progress.toFloat().coerceIn(0f, 1f), spring(), label = "ring")
    Canvas(modifier) {
        val w = stroke.toPx()
        drawArc(tint.copy(alpha = 0.15f), 0f, 360f, false, style = Stroke(w), topLeft = Offset(w / 2, w / 2), size = size.copy(size.width - w, size.height - w))
        drawArc(tint, -90f, 360f * animated, false, style = Stroke(w, cap = StrokeCap.Round), topLeft = Offset(w / 2, w / 2), size = size.copy(size.width - w, size.height - w))
    }
}

/** Initials or image avatar with a stable accent. */
@Composable
fun Avatar(name: String, imageFile: File? = null, size: Dp = 40.dp, icon: ImageVector? = null) {
    val shape = RoundedCornerShape(size * 0.3f)
    if (imageFile != null) {
        AsyncImage(imageFile, null, Modifier.size(size).clip(shape), contentScale = ContentScale.Crop)
        return
    }
    val accent = Tokens.accent(name)
    Box(
        Modifier.size(size).clip(shape).background(Brush.verticalGradient(listOf(accent, accent.copy(alpha = 0.8f)))),
        contentAlignment = Alignment.Center,
    ) {
        if (icon != null) Icon(icon, null, tint = Color.White, modifier = Modifier.size(size * 0.45f))
        else Text(initials(name), color = Color.White, fontWeight = FontWeight.Bold, fontSize = (size.value * 0.38f).sp)
    }
}

private fun initials(name: String) = name.split(" ").filter { it.isNotBlank() }.take(2).joinToString("") { it.first().uppercase() }.ifEmpty { "?" }

/** Style/project image with a woven placeholder. */
@Composable
fun Swatch(name: String, imageFile: File?, modifier: Modifier = Modifier, corner: Dp = 16.dp) {
    val shape = RoundedCornerShape(corner)
    if (imageFile != null) {
        AsyncImage(imageFile, name, modifier.clip(shape), contentScale = ContentScale.Crop)
        return
    }
    val accent = Tokens.accent(name)
    Box(modifier.clip(shape).background(Brush.verticalGradient(listOf(accent, accent.copy(alpha = 0.75f)))), contentAlignment = Alignment.Center) {
        WeaveTexture(spacing = 26f, ink = Color.White.copy(alpha = 0.16f))
        Icon(Icons.Outlined.Checkroom, null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(28.dp))
    }
}

@Composable
fun PrimaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, icon: ImageVector? = null, tint: Color = Tokens.colors.brand) {
    Button(
        onClick, modifier.height(54.dp), enabled = enabled, shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(containerColor = tint, contentColor = Color.White),
        contentPadding = PaddingValues(horizontal = 22.dp),
    ) {
        Text(text, style = MaterialTheme.typography.labelLarge)
        if (icon != null) { Spacer(Modifier.width(8.dp)); Icon(icon, null, Modifier.size(18.dp)) }
    }
}

/** Text field styled for forms; [numeric] switches the keyboard. */
@Composable
fun TramaField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    keyboard: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = true,
    leading: ImageVector? = null,
    supporting: String? = null,
    isError: Boolean = false,
) {
    OutlinedTextField(
        value, onValueChange, modifier.fillMaxWidth(), label = { Text(label) }, singleLine = singleLine,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        leadingIcon = leading?.let { { Icon(it, null, tint = Tokens.colors.brand) } },
        supportingText = supporting?.let { { Text(it) } }, isError = isError,
        shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface),
    )
}

/** Integer field that keeps a String buffer so users can clear it while typing. */
@Composable
fun IntField(value: Int, onValueChange: (Int) -> Unit, label: String, modifier: Modifier = Modifier) {
    var text by remember(value == 0) { mutableStateOf(if (value == 0) "" else value.toString()) }
    TramaField(text, { raw ->
        val digits = raw.filter(Char::isDigit).take(9)
        text = digits
        onValueChange(digits.toIntOrNull() ?: 0)
    }, label, modifier, keyboard = KeyboardType.Number)
}

@Composable
fun DecimalField(value: Double, onValueChange: (Double) -> Unit, label: String, modifier: Modifier = Modifier) {
    var text by remember { mutableStateOf(if (value == 0.0) "" else Fmt.number(value, 2).replace(",", "")) }
    TramaField(text, { raw ->
        val cleaned = raw.filter { it.isDigit() || it == '.' }.let { s -> val i = s.indexOf('.'); if (i >= 0) s.substring(0, i + 1) + s.substring(i + 1).replace(".", "") else s }
        text = cleaned
        onValueChange(cleaned.toDoubleOrNull() ?: 0.0)
    }, label, modifier, keyboard = KeyboardType.Decimal)
}

/** Centered empty state, like SwiftUI's ContentUnavailableView. */
@Composable
fun EmptyState(title: String, message: String, icon: ImageVector, modifier: Modifier = Modifier, action: (@Composable () -> Unit)? = null) {
    Column(modifier.fillMaxWidth().padding(40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Icon(icon, null, tint = Tokens.colors.secondary.copy(alpha = 0.6f), modifier = Modifier.size(48.dp))
        Text(title, style = MaterialTheme.typography.titleLarge)
        Text(message, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
        action?.invoke()
    }
}

/** Bordered surface for list rows. */
@Composable
fun RowCard(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable RowScope.() -> Unit) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = Tokens.colors.surface,
        border = BorderStroke(1.dp, Tokens.colors.stroke),
        onClick = onClick ?: {},
        enabled = onClick != null,
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp), content = content)
    }
}

@Composable
fun Dot(color: Color, size: Dp = 8.dp) = Box(Modifier.size(size).clip(CircleShape).background(color))
