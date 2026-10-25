package com.nevutech.trama

import android.os.Bundle
import android.util.Log
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

private const val TAG = "Trama"

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as TramaApplication
        // Debug QA hook, same contract as iOS -uiTestDemo: in-memory demo store + optional auto sign-in.
        // adb shell am start -n com.nevutech.trama/.MainActivity --ez uiTestDemo true --es loginAs admin@demo.local --es openSection Board [--es openRoute firstAssignment|firstOrder]
        val container = if (BuildConfig.DEBUG && intent.getBooleanExtra("uiTestDemo", false)) {
            AppContainer(this, TramaDatabase.inMemory(this)).also { demo ->
                lifecycleScope.launch(kotlinx.coroutines.Dispatchers.Default) {
                    runCatching {
                        DemoSeeder.seed(demo.db)
                        demo.settings.setDemoSeeded(true)
                        demo.settings.setCompanyName(DemoSeeder.DEMO_COMPANY)
                        Log.i(TAG, "demo seeded: ${demo.db.dao().userCount()} users")
                        intent.getStringExtra("loginAs")?.let { demo.session.signIn(it, DemoSeeder.DEMO_PASSWORD) }
                    }.onFailure { Log.e(TAG, "demo launch failed", it) }
                }
            }
        } else app.container
        val startSection = intent.getStringExtra("openSection")
        val startRoute = intent.getStringExtra("openRoute")
        setContent {
            TramaTheme {
                CompositionLocalProvider(LocalApp provides container) {
                    RootScreen(debugStartSection = startSection, debugStartRoute = startRoute)
                }
            }
        }
    }
}
