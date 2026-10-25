package com.nevutech.trama.designsystem

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Non-blocking feedback (same pattern as iOS ToastCenter): every write reports through here. */
class ToastCenter {
    enum class Style { Success, Error, Info }
    data class Toast(val message: String, val style: Style, val id: Long = System.nanoTime())

    private val _current = MutableStateFlow<Toast?>(null)
    val current: StateFlow<Toast?> = _current.asStateFlow()

    fun show(message: String, style: Style = Style.Success) { _current.value = Toast(message, style) }
    fun error(error: Throwable) = show(error.message ?: "Ocurrió un error.", Style.Error)
    fun dismiss() { _current.value = null }
}

@Composable
fun ToastHost(center: ToastCenter) {
    val toast by center.current.collectAsState()
    val haptics = LocalHapticFeedback.current
    LaunchedEffect(toast?.id) {
        val t = toast ?: return@LaunchedEffect
        haptics.performHapticFeedback(if (t.style == ToastCenter.Style.Error) HapticFeedbackType.Reject else HapticFeedbackType.Confirm)
        delay(if (t.style == ToastCenter.Style.Error) 4_000 else 2_400)
        center.dismiss()
    }
    Box(Modifier.fillMaxSize().navigationBarsPadding().padding(bottom = 28.dp), contentAlignment = Alignment.BottomCenter) {
        val last = remember(toast) { toast }
        AnimatedVisibility(toast != null, enter = slideInVertically { it } + fadeIn(), exit = slideOutVertically { it } + fadeOut()) {
            last?.let { t ->
                val tint = when (t.style) {
                    ToastCenter.Style.Success -> Tokens.colors.success
                    ToastCenter.Style.Error -> Tokens.colors.danger
                    ToastCenter.Style.Info -> Tokens.colors.info
                }
                Surface(
                    onClick = center::dismiss,
                    shape = Tokens.chipShape,
                    color = Tokens.colors.surface,
                    border = BorderStroke(1.dp, tint.copy(alpha = 0.35f)),
                    shadowElevation = 12.dp,
                    modifier = Modifier.widthIn(max = 560.dp).semantics { liveRegion = LiveRegionMode.Polite },
                ) {
                    Row(Modifier.padding(horizontal = 20.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                        val icon = when (t.style) {
                            ToastCenter.Style.Success -> Icons.Filled.CheckCircle
                            ToastCenter.Style.Error -> Icons.Filled.Error
                            ToastCenter.Style.Info -> Icons.Filled.Info
                        }
                        Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp))
                        Text(t.message, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(start = 12.dp))
                    }
                }
            }
        }
    }
}
