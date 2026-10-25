package com.nevutech.trama.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.nevutech.trama.R
import com.nevutech.trama.core.data.fullName
import com.nevutech.trama.core.data.roleValue
import com.nevutech.trama.core.domain.AppSection
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.feature.calculator.CalculatorScreen
import com.nevutech.trama.feature.clients.ClientDetailScreen
import com.nevutech.trama.feature.clients.ClientsScreen
import com.nevutech.trama.feature.clients.SupplierDetailScreen
import com.nevutech.trama.feature.clients.SuppliersScreen
import com.nevutech.trama.feature.dashboard.DashboardScreen
import com.nevutech.trama.feature.orders.OrderDetailScreen
import com.nevutech.trama.feature.orders.OrdersScreen
import com.nevutech.trama.feature.plants.PlantCalendarScreen
import com.nevutech.trama.feature.plants.PlantDetailScreen
import com.nevutech.trama.feature.plants.PlantsScreen
import com.nevutech.trama.feature.production.AssignmentDetailScreen
import com.nevutech.trama.feature.production.CutBoardScreen
import com.nevutech.trama.feature.projects.ProjectsScreen
import com.nevutech.trama.feature.reports.ProductionReportsScreen
import com.nevutech.trama.feature.settings.SettingsScreen
import com.nevutech.trama.feature.shipments.UrgentShipmentsScreen
import com.nevutech.trama.feature.styles.StyleDetailScreen
import com.nevutech.trama.feature.styles.StylesScreen
import com.nevutech.trama.feature.users.UsersScreen
import kotlinx.coroutines.launch

/**
 * Adaptive shell: permanent sidebar on large tablets (like the iPad split view), a rail on
 * medium widths and a modal drawer on phones. Sections are filtered by the user's role.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainShell(debugStartSection: String? = null, debugStartRoute: String? = null) {
    val app = LocalApp.current
    val user by app.session.user.collectAsState()
    val role = app.session.role
    val sections = role.sections
    val start = debugStartSection?.let { name -> AppSection.entries.firstOrNull { it.name == name } }?.takeIf { it in sections } ?: role.landing

    val nav = rememberNavController()
    val navigator = remember(nav) { AppNavigator(nav) }
    val backStack by nav.currentBackStackEntryAsState()
    val currentSection = backStack?.arguments?.getString("name")?.let { n -> AppSection.entries.firstOrNull { it.name == n } }
    val width = LocalConfiguration.current.screenWidthDp
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var confirmSignOut by remember { mutableStateOf(false) }

    // DEBUG QA hook (iOS parity): open the first assignment/order once the graph has data.
    val graphForRoute by rememberGraph()
    var routeOpened by remember { mutableStateOf(false) }
    androidx.compose.runtime.LaunchedEffect(graphForRoute, debugStartRoute) {
        if (routeOpened || debugStartRoute == null) return@LaunchedEffect
        when (debugStartRoute) {
            "firstAssignment" -> graphForRoute.assignments.minByOrNull { it.scheduledDate ?: Long.MAX_VALUE }?.let { routeOpened = true; navigator.openAssignment(it.id) }
            "firstOrder" -> graphForRoute.orders.minByOrNull { it.code }?.let { routeOpened = true; navigator.openOrder(it.id) }
        }
    }

    val select: (AppSection) -> Unit = { section ->
        navigator.openSection(section)
        scope.launch { drawerState.close() }
    }

    val host: @Composable (Modifier) -> Unit = { modifier ->
        CompositionLocalProvider(LocalNavigator provides navigator) {
            NavHost(nav, startDestination = Routes.section(start), modifier = modifier) {
                composable(Routes.SECTION_PATTERN, arguments = listOf(navArgument("name") { type = NavType.StringType })) { entry ->
                    val section = AppSection.entries.firstOrNull { it.name == entry.arguments?.getString("name") } ?: start
                    SectionScreen(if (section in sections) section else start)
                }
                detail(Routes.ASSIGNMENT) { AssignmentDetailScreen(it) }
                detail(Routes.ORDER) { OrderDetailScreen(it) }
                detail(Routes.PLANT) { PlantDetailScreen(it) }
                detail(Routes.CLIENT) { ClientDetailScreen(it) }
                detail(Routes.SUPPLIER) { SupplierDetailScreen(it) }
                detail(Routes.STYLE) { StyleDetailScreen(it) }
            }
        }
    }

    val sidebar: @Composable () -> Unit = {
        Sidebar(sections, currentSection, onSelect = select, onSignOut = { confirmSignOut = true })
    }

    when {
        width >= 1000 -> Row(Modifier.fillMaxSize()) {
            Box(Modifier.width(290.dp).fillMaxHeight()) { sidebar() }
            host(Modifier.weight(1f).fillMaxHeight().statusBarsPadding())
        }
        width >= 600 -> Row(Modifier.fillMaxSize()) {
            NavigationRail(containerColor = Tokens.colors.surfaceRaised, modifier = Modifier.statusBarsPadding()) {
                Spacer(Modifier.height(8.dp))
                sections.forEach { section ->
                    NavigationRailItem(
                        selected = section == currentSection, onClick = { select(section) },
                        icon = { Icon(section.icon, section.title) }, label = { Text(section.title.substringBefore(" "), maxLines = 1) },
                    )
                }
                Spacer(Modifier.weight(1f))
                NavigationRailItem(false, { confirmSignOut = true }, icon = { Icon(Icons.AutoMirrored.Filled.Logout, "Cerrar sesión") })
            }
            host(Modifier.weight(1f).fillMaxHeight().statusBarsPadding())
        }
        else -> ModalNavigationDrawer(drawerContent = { ModalDrawerSheet { sidebar() } }, drawerState = drawerState) {
            Column(Modifier.fillMaxSize()) {
                TopAppBar(
                    title = { Text(currentSection?.title ?: "Trama") },
                    navigationIcon = { IconButton({ scope.launch { drawerState.open() } }) { Icon(Icons.Filled.Menu, "Menú") } },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Tokens.colors.canvas),
                )
                host(Modifier.weight(1f))
            }
        }
    }

    if (confirmSignOut) {
        AlertDialog(
            onDismissRequest = { confirmSignOut = false },
            title = { Text("¿Cerrar sesión?") },
            text = { Text("Tus datos se quedan guardados en este dispositivo.") },
            confirmButton = { TextButton({ confirmSignOut = false; scope.launch { app.session.signOut() } }) { Text("Cerrar sesión", color = Tokens.colors.danger) } },
            dismissButton = { TextButton({ confirmSignOut = false }) { Text("Cancelar") } },
        )
    }
}

private fun androidx.navigation.NavGraphBuilder.detail(route: String, content: @Composable (String) -> Unit) {
    composable(route, arguments = listOf(navArgument("id") { type = NavType.StringType })) { entry ->
        content(entry.arguments?.getString("id").orEmpty())
    }
}

@Composable
private fun SectionScreen(section: AppSection) = when (section) {
    AppSection.Dashboard -> DashboardScreen()
    AppSection.Orders -> OrdersScreen()
    AppSection.Board -> CutBoardScreen()
    AppSection.Production -> ProductionReportsScreen()
    AppSection.Shipments -> UrgentShipmentsScreen()
    AppSection.Calendar -> PlantCalendarScreen()
    AppSection.Plants -> PlantsScreen()
    AppSection.Clients -> ClientsScreen()
    AppSection.Suppliers -> SuppliersScreen()
    AppSection.Styles -> StylesScreen()
    AppSection.Projects -> ProjectsScreen()
    AppSection.Users -> UsersScreen()
    AppSection.Calculator -> CalculatorScreen()
    AppSection.Settings -> SettingsScreen()
}

@Composable
private fun Sidebar(sections: List<AppSection>, current: AppSection?, onSelect: (AppSection) -> Unit, onSignOut: () -> Unit) {
    val app = LocalApp.current
    val graph by rememberGraph()
    val user by app.session.user.collectAsState()
    val urgency by app.settings.urgencyWindowDays.collectAsState(initial = 7)
    val visible = graph.visibleAssignments(user)
    val pendingOrders = graph.orders.count { graph.remaining(it) > 0 }
    val urgent = visible.count { graph.isUrgent(it, urgency) }

    Column(Modifier.fillMaxHeight().background(Tokens.colors.surfaceRaised).statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 18.dp), verticalAlignment = Alignment.CenterVertically) {
            androidx.compose.foundation.Image(painterResource(R.drawable.trama_mark), null, Modifier.size(34.dp).clip(RoundedCornerShape(9.dp)))
            Text("Trama", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.ExtraBold, modifier = Modifier.padding(start = 10.dp))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 12.dp)) {
            AppSection.Group.entries.forEach { group ->
                val items = sections.filter { it.group == group }
                if (items.isNotEmpty()) {
                    Text(group.title, style = MaterialTheme.typography.labelMedium, color = Tokens.colors.secondary, modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 6.dp))
                    items.forEach { section ->
                        val badge = when (section) {
                            AppSection.Orders -> pendingOrders
                            AppSection.Shipments -> urgent
                            else -> 0
                        }
                        NavigationDrawerItem(
                            label = { Text(section.title) },
                            icon = { Icon(section.icon, null, tint = Tokens.colors.brand) },
                            badge = { if (badge > 0) Text("$badge", color = Tokens.colors.secondary) },
                            selected = section == current,
                            onClick = { onSelect(section) },
                            colors = NavigationDrawerItemDefaults.colors(selectedContainerColor = Tokens.colors.brand.copy(alpha = 0.12f)),
                        )
                    }
                }
            }
        }
        user?.let { u ->
            Row(
                Modifier.padding(12.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Tokens.colors.surface).padding(14.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Avatar(u.fullName, app.images.file(u.avatarFile), 42.dp)
                Column(Modifier.weight(1f)) {
                    Text(u.fullName, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                    Text(u.roleValue.title, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                }
                IconButton(onSignOut) { Icon(Icons.AutoMirrored.Filled.Logout, "Cerrar sesión", tint = Tokens.colors.brand) }
            }
        }
    }
}

