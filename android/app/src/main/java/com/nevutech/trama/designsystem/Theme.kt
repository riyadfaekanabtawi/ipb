package com.nevutech.trama.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.OrderAssignmentState
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.ReportKind
import kotlin.math.abs

/** Trama tokens; same palette as ios/Trama/DesignSystem/Theme.swift (petrol-teal warp, thread-yellow weft, linen). */
@Immutable
data class TramaColors(
    val brand: Color,
    val brandDeep: Color,
    val thread: Color,
    val success: Color,
    val warning: Color,
    val danger: Color,
    val info: Color,
    val canvas: Color,
    val surface: Color,
    val surfaceRaised: Color,
    val stroke: Color,
    val ink: Color,
    val secondary: Color,
    val isDark: Boolean,
)

private val Light = TramaColors(
    brand = Color(0xFF145C6E), brandDeep = Color(0xFF0B3440), thread = Color(0xFFE8B314),
    success = Color(0xFF2E9E5B), warning = Color(0xFFD98A06), danger = Color(0xFFD93A3F), info = Color(0xFF3E63DD),
    canvas = Color(0xFFF4F1EA), surface = Color.White, surfaceRaised = Color(0xFFFBFAF6),
    stroke = Color(0x140B3440), ink = Color(0xFF0B1F26), secondary = Color(0xFF5E7178), isDark = false,
)

private val Dark = TramaColors(
    brand = Color(0xFF3FA7BD), brandDeep = Color(0xFF0B2A33), thread = Color(0xFFF4C430),
    success = Color(0xFF3DD68C), warning = Color(0xFFF5B23D), danger = Color(0xFFFF6369), info = Color(0xFF7B93FF),
    canvas = Color(0xFF0A1418), surface = Color(0xFF12212A), surfaceRaised = Color(0xFF182B35),
    stroke = Color(0x17FFFFFF), ink = Color(0xFFEEF3F4), secondary = Color(0xFF9DB0B6), isDark = true,
)

val LocalTramaColors = staticCompositionLocalOf { Light }

object Tokens {
    val colors: TramaColors @Composable get() = LocalTramaColors.current
    val radius = 22.dp
    val smallRadius = 14.dp
    val cardShape = RoundedCornerShape(22.dp)
    val chipShape = RoundedCornerShape(50)

    /** Stable accent for a name (plants, clients, styles), used for avatars and chart series. */
    fun accent(key: String): Color {
        val palette = listOf(0xFF145C6E, 0xFFE8A317, 0xFF6E56CF, 0xFF2E9E5B, 0xFFD93A3F, 0xFF3E63DD, 0xFFC2410C, 0xFF0E7490)
        var hash = 5381
        key.forEach { hash = (hash shl 5) + hash + it.code }
        return Color(palette[abs(hash) % palette.size])
    }
}

@Composable fun CutStatus.tint(): Color = when (this) {
    CutStatus.Waiting -> Tokens.colors.danger
    CutStatus.OnTable -> Tokens.colors.warning
    CutStatus.Ready -> Tokens.colors.success
}

@Composable fun ReportKind.tint(): Color = when (this) {
    ReportKind.Plant -> Tokens.colors.brand
    ReportKind.Cut -> Tokens.colors.warning
    ReportKind.Shipment -> Tokens.colors.info
}

@Composable fun ProjectStatus.tint(): Color = when (this) {
    ProjectStatus.Pending -> Tokens.colors.secondary
    ProjectStatus.Accepted -> Tokens.colors.success
    ProjectStatus.Declined -> Tokens.colors.danger
}

@Composable fun OrderAssignmentState.tint(): Color = when (this) {
    OrderAssignmentState.Unassigned -> Tokens.colors.danger
    OrderAssignmentState.Partial -> Tokens.colors.warning
    OrderAssignmentState.Assigned -> Tokens.colors.success
}

private val Display = FontFamily.SansSerif

private val TramaTypography = Typography(
    displaySmall = TextStyle(fontFamily = Display, fontWeight = FontWeight.ExtraBold, fontSize = 34.sp, letterSpacing = (-0.5).sp),
    headlineMedium = TextStyle(fontFamily = Display, fontWeight = FontWeight.Bold, fontSize = 28.sp, letterSpacing = (-0.4).sp),
    headlineSmall = TextStyle(fontFamily = Display, fontWeight = FontWeight.Bold, fontSize = 24.sp),
    titleLarge = TextStyle(fontWeight = FontWeight.Bold, fontSize = 20.sp),
    titleMedium = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 17.sp),
    titleSmall = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
    bodyLarge = TextStyle(fontSize = 17.sp, lineHeight = 24.sp),
    bodyMedium = TextStyle(fontSize = 15.sp, lineHeight = 21.sp),
    bodySmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
    labelMedium = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 13.sp),
    labelSmall = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 11.sp),
)

@Composable
fun TramaTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val c = if (dark) Dark else Light
    val scheme = if (dark) {
        darkColorScheme(primary = c.brand, onPrimary = Color(0xFF04161B), secondary = c.thread, background = c.canvas,
            surface = c.surface, onSurface = c.ink, onBackground = c.ink, surfaceVariant = c.surfaceRaised, error = c.danger,
            surfaceContainer = c.surface, surfaceContainerHigh = c.surfaceRaised, surfaceContainerLow = c.canvas)
    } else {
        lightColorScheme(primary = c.brand, onPrimary = Color.White, secondary = c.thread, background = c.canvas,
            surface = c.surface, onSurface = c.ink, onBackground = c.ink, surfaceVariant = c.surfaceRaised, error = c.danger,
            surfaceContainer = c.surface, surfaceContainerHigh = c.surfaceRaised, surfaceContainerLow = c.canvas)
    }
    CompositionLocalProvider(LocalTramaColors provides c) {
        MaterialTheme(
            colorScheme = scheme,
            typography = TramaTypography,
            shapes = Shapes(small = RoundedCornerShape(10.dp), medium = RoundedCornerShape(16.dp), large = RoundedCornerShape(22.dp)),
        ) {
            // Screens draw on custom canvases rather than Material Surfaces, so set the default
            // text/icon color explicitly; otherwise it falls back to black in dark mode.
            CompositionLocalProvider(LocalContentColor provides c.ink, content = content)
        }
    }
}
