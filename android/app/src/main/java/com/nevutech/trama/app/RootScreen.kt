package com.nevutech.trama.app

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.nevutech.trama.designsystem.ToastHost
import com.nevutech.trama.feature.auth.LoginScreen
import com.nevutech.trama.feature.auth.OnboardingScreen

/** Switches between onboarding (no users yet), sign in, and the main shell. */
@Composable
fun RootScreen(debugStartSection: String? = null) {
    val app = LocalApp.current
    val user by app.session.user.collectAsState()
    val userCount by app.db.dao().userCountFlow().collectAsState(initial = -1)
    val graph by rememberGraph()
    var restored by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        app.session.restore()
        restored = true
    }
    // Keep the signed-in user in sync with edits made elsewhere (role change, deactivation, restore).
    LaunchedEffect(graph) { app.session.refresh(graph) }

    val phase = when {
        !restored || userCount < 0 -> Phase.Loading
        user != null -> Phase.Main
        userCount == 0 -> Phase.Onboarding
        else -> Phase.Login
    }
    Box {
        AnimatedContent(phase, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "root") { p ->
            when (p) {
                Phase.Loading -> Box {}
                Phase.Onboarding -> OnboardingScreen()
                Phase.Login -> LoginScreen()
                Phase.Main -> MainShell(debugStartSection)
            }
        }
        ToastHost(app.toasts)
    }
}

private enum class Phase { Loading, Onboarding, Login, Main }
