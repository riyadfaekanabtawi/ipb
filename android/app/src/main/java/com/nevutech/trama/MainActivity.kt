package com.nevutech.trama

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.lifecycle.lifecycleScope
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.RootScreen
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.designsystem.TramaTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as TramaApplication
        // Debug QA hook, same contract as iOS -uiTestDemo: in-memory demo store + optional auto sign-in.
        // adb shell am start -n com.nevutech.trama/.MainActivity --ez uiTestDemo true --es loginAs admin@demo.local --es openSection Board
        val container = if (BuildConfig.DEBUG && intent.getBooleanExtra("uiTestDemo", false)) {
            AppContainer(this, TramaDatabase.inMemory(this)).also { demo ->
                lifecycleScope.launch {
                    DemoSeeder.seed(demo.db)
                    demo.settings.setDemoSeeded(true)
                    demo.settings.setCompanyName(DemoSeeder.DEMO_COMPANY)
                    intent.getStringExtra("loginAs")?.let { runCatching { demo.session.signIn(it, DemoSeeder.DEMO_PASSWORD) } }
                }
            }
        } else app.container
        val startSection = intent.getStringExtra("openSection")
        setContent {
            TramaTheme {
                CompositionLocalProvider(LocalApp provides container) {
                    RootScreen(debugStartSection = startSection)
                }
            }
        }
    }
}
