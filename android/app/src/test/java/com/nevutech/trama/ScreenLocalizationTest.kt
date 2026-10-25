package com.nevutech.trama

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.core.app.ApplicationProvider
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.designsystem.TramaTheme
import com.nevutech.trama.feature.auth.LoginScreen
import com.nevutech.trama.feature.auth.OnboardingScreen
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Renders real screens and checks they read the translated resources. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ScreenLocalizationTest {
    @get:Rule val compose = createComposeRule()

    private fun show(content: @androidx.compose.runtime.Composable () -> Unit) {
        val app = ApplicationProvider.getApplicationContext<TramaApplication>().container
        compose.mainClock.autoAdvance = false
        compose.setContent { TramaTheme { CompositionLocalProvider(LocalApp provides app) { content() } } }
        compose.mainClock.advanceTimeBy(1_000)
    }

    private fun assertShown(text: String) {
        compose.onNodeWithText(text, useUnmergedTree = true).assertExists()
    }

    @Test fun loginInSpanishByDefault() {
        show { LoginScreen() }
        assertShown("Conectar con mi licencia")
    }

    @Test @Config(qualifiers = "en")
    fun loginInEnglish() {
        show { LoginScreen() }
        assertShown("Welcome back")
        assertShown("Sign in")
        assertShown("Connect my licence")
    }

    @Test @Config(qualifiers = "pt-rBR")
    fun onboardingInPortuguese() {
        show { OnboardingScreen() }
        assertShown("Conectar minha licença")
        compose.onNodeWithText("Bem-vindo de volta").assertDoesNotExist()
    }
}
