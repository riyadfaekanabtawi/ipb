package com.nevutech.trama.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.navigation.NavHostController
import com.nevutech.trama.AppContainer
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.domain.AppSection
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

val LocalApp = compositionLocalOf<AppContainer> { error("AppContainer not provided") }
val LocalNavigator = compositionLocalOf<AppNavigator> { error("AppNavigator not provided") }

/** Route strings used by the NavHost. Detail routes carry entity ids. */
object Routes {
    fun section(section: AppSection) = "section/${section.name}"
    const val SECTION_PATTERN = "section/{name}"
    const val ASSIGNMENT = "assignment/{id}"
    const val ORDER = "order/{id}"
    const val PLANT = "plant/{id}"
    const val CLIENT = "client/{id}"
    const val SUPPLIER = "supplier/{id}"
    const val STYLE = "style/{id}"
}

/** Thin, typed wrapper over the NavController so screens never build route strings. */
class AppNavigator(private val nav: NavHostController) {
    fun openSection(section: AppSection) = nav.navigate(Routes.section(section)) {
        popUpTo(nav.graph.id) { inclusive = true }
        launchSingleTop = true
    }
    fun openAssignment(id: String) = nav.navigate("assignment/$id")
    fun openOrder(id: String) = nav.navigate("order/$id")
    fun openPlant(id: String) = nav.navigate("plant/$id")
    fun openClient(id: String) = nav.navigate("client/$id")
    fun openSupplier(id: String) = nav.navigate("supplier/$id")
    fun openStyle(id: String) = nav.navigate("style/$id")
    fun back() = nav.popBackStack()
}

/** Live database snapshot for the current screen. */
@Composable
fun rememberGraph(): State<Graph> = LocalApp.current.repository.graph.collectAsState()

/**
 * Runs a write off the main thread and reports through the toast center:
 * `run({ service.assign(...) }, success = "Asignado")`.
 */
class ActionRunner(private val app: AppContainer, private val scope: CoroutineScope) {
    fun run(success: String? = null, onDone: () -> Unit = {}, block: suspend () -> Unit) {
        scope.launch {
            runCatching { block() }
                .onSuccess { success?.let(app.toasts::show); onDone() }
                .onFailure(app.toasts::error)
        }
    }
}

@Composable
fun rememberActions(): ActionRunner = ActionRunner(LocalApp.current, rememberCoroutineScope())
