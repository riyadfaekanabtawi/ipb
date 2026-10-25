package com.nevutech.trama.designsystem

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlin.math.PI
import kotlin.math.sin

/** Very subtle plain-weave texture used behind every screen. */
@Composable
fun WeaveTexture(modifier: Modifier = Modifier, spacing: Float = 42f, ink: Color = Tokens.colors.brandDeep.copy(alpha = 0.035f)) {
    Canvas(modifier.fillMaxSize()) {
        var column = 0
        var x = 0f
        while (x < size.width) {
            var row = 0
            var y = 0f
            while (y < size.height) {
                val horizontal = (row + column) % 2 == 0
                if (horizontal) {
                    drawRoundRect(ink, Offset(x + 6, y + spacing / 2 - 3), Size(spacing - 12, 6f), CornerRadius(3f))
                } else {
                    drawRoundRect(ink, Offset(x + spacing / 2 - 3, y + 6), Size(6f, spacing - 12), CornerRadius(3f))
                }
                y += spacing; row++
            }
            x += spacing; column++
        }
    }
}

/** Animated loom of flowing threads (login and dashboard hero), same motif as iOS and the website. */
@Composable
fun ThreadField(modifier: Modifier = Modifier, threads: Int = 18) {
    val time by rememberInfiniteTransition(label = "loom").animateFloat(
        initialValue = 0f, targetValue = (2 * PI).toFloat() * 10,
        animationSpec = infiniteRepeatable(tween(120_000, easing = LinearEasing), RepeatMode.Restart), label = "t",
    )
    val colors = listOf(Color(0xFFF4C430), Color.White, Color(0xFF3FA7BD))
    Canvas(modifier.fillMaxSize()) {
        for (i in 0 until threads) {
            val p = i.toFloat() / threads
            val baseY = size.height * (0.08f + 0.84f * p)
            val amplitude = size.height * (0.03f + 0.05f * sin(p * PI).toFloat())
            val frequency = 1.4f + 0.9f * sin(i * 1.7f)
            val phase = time * (0.6f + p) + i
            val path = Path()
            val steps = 48
            for (s in 0..steps) {
                val u = s.toFloat() / steps
                val y = baseY + amplitude * sin(u * PI.toFloat() * 2 * frequency + phase) + amplitude * 0.35f * sin(u * PI.toFloat() * 7 + phase * 1.3f)
                if (s == 0) path.moveTo(0f, y) else path.lineTo(size.width * u, y)
            }
            val alpha = 0.10f + 0.22f * (0.5f + 0.5f * sin(phase * 0.7f))
            drawPath(path, colors[i % colors.size].copy(alpha = alpha), style = Stroke(width = if (i % 5 == 0) 4f else 2f))
        }
    }
}

/** Brand hero backdrop: teal gradient + flowing threads + a warm glow. */
@Composable
fun LoomBackdrop(modifier: Modifier = Modifier) {
    Box(
        modifier
            .background(Brush.linearGradient(listOf(Color(0xFF0B3440), Color(0xFF145C6E), Color(0xFF1F7A8C))))
    ) {
        ThreadField()
        Box(Modifier.fillMaxSize().background(Brush.radialGradient(listOf(Color(0x40F4C430), Color.Transparent), radius = 900f, center = Offset(2000f, 0f))))
    }
}
