package com.nevutech.trama.feature.settings

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Restore
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.app.rememberIsOnline
import com.nevutech.trama.core.data.AuthError
import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.PasswordHasher
import com.nevutech.trama.core.data.Session
import com.nevutech.trama.core.data.UserEntity
import com.nevutech.trama.core.data.eraseAllData
import com.nevutech.trama.core.data.fullName
import com.nevutech.trama.core.data.roleValue
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.Role as UserRole
import com.nevutech.trama.core.l10n.AppLanguage
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.ToastCenter
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.feature.auth.CloudSignInDialog
import java.time.ZoneId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Port of ios SettingsView: account, preferences, data (backup / restore / demo / erase) and about. */
@Composable
fun SettingsScreen() {
    val app = LocalApp.current
    val actions = rememberActions()
    val context = LocalContext.current
    val graph by rememberGraph()
    val user by app.session.user.collectAsState()
    val isAdmin = user?.roleValue == UserRole.Admin

    var showPassword by remember { mutableStateOf(false) }
    var confirmSignOut by remember { mutableStateOf(false) }
    var pendingRestore by remember { mutableStateOf<PendingRestore?>(null) }
    var confirmErase by remember { mutableStateOf(false) }
    var confirmEraseFinal by remember { mutableStateOf(false) }

    val exporter = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        actions.run(success = L10n.str(R.string.settings_backup_saved)) {
            val bytes = BackupService.export(app.db, app.images)
            withContext(Dispatchers.IO) {
                context.contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) } ?: error(L10n.str(R.string.settings_file_write_failed))
            }
        }
    }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        actions.run {
            val bytes = withContext(Dispatchers.IO) {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: error(L10n.str(R.string.settings_file_read_failed))
            }
            val summary = withContext(Dispatchers.Default) { BackupService.inspect(bytes) }
            pendingRestore = PendingRestore(bytes, summary)
        }
    }

    TramaScreen {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 760.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(22.dp)) {
                if (LocalConfiguration.current.screenWidthDp >= 600) Text(stringResource(R.string.section_settings), style = MaterialTheme.typography.headlineMedium)
                AccountSection(user, graph.plant(user?.plantId)?.name) { showPassword = true }
                PreferencesSection(isAdmin)
                LanguageSection()
                CloudSection(isAdmin)
                DataSection(
                    isAdmin = isAdmin,
                    onExport = { exporter.launch(BackupService.filename()) },
                    onRestore = { importer.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) },
                    onDemo = {
                        val operational = graph.plants.size + graph.orders.size + graph.clients.size + graph.styles.size
                        if (app.sync.status.value.connected) {
                            app.toasts.show(L10n.str(R.string.settings_demo_blocked_cloud), ToastCenter.Style.Info)
                        } else if (operational > 0) {
                            app.toasts.show(L10n.str(R.string.settings_demo_blocked_data), ToastCenter.Style.Info)
                        } else {
                            actions.run(success = L10n.str(R.string.settings_demo_loaded, DemoSeeder.DEMO_PASSWORD)) {
                                DemoSeeder.seed(app.db)
                                app.settings.setDemoSeeded(true)
                                app.settings.setCompanyName(DemoSeeder.DEMO_COMPANY)
                            }
                        }
                    },
                    onErase = { confirmErase = true },
                )
                AboutSection()
                OutlinedButton(
                    { confirmSignOut = true }, Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp),
                ) {
                    Icon(Icons.AutoMirrored.Filled.Logout, null, tint = Tokens.colors.danger, modifier = Modifier.size(18.dp))
                    Text(stringResource(R.string.common_sign_out), color = Tokens.colors.danger, modifier = Modifier.padding(start = 8.dp))
                }
            }
        }
    }

    if (showPassword) user?.let { ChangePasswordDialog(it) { showPassword = false } }

    if (confirmSignOut) {
        AlertDialog(
            onDismissRequest = { confirmSignOut = false },
            title = { Text(stringResource(R.string.shell_sign_out_title)) },
            text = { Text(stringResource(R.string.shell_sign_out_message)) },
            confirmButton = {
                TextButton({ confirmSignOut = false; actions.run { app.session.signOut() } }) { Text(stringResource(R.string.common_sign_out), color = Tokens.colors.danger) }
            },
            dismissButton = { TextButton({ confirmSignOut = false }) { Text(stringResource(R.string.common_cancel)) } },
        )
    }

    pendingRestore?.let { pending ->
        AlertDialog(
            onDismissRequest = { pendingRestore = null },
            icon = { Icon(Icons.Filled.Warning, null, tint = Tokens.colors.warning) },
            title = { Text(stringResource(R.string.settings_restore_title)) },
            text = { Text(pending.message()) },
            confirmButton = {
                TextButton({
                    pendingRestore = null
                    actions.run {
                        withContext(Dispatchers.Default) { BackupService.restore(pending.bytes, app.db, app.images) }
                        app.session.restore()
                        if (app.session.user.value != null) {
                            app.toasts.show(L10n.plural(R.plurals.settings_restore_done, pending.summary.total, Fmt.int(pending.summary.total)))
                        } else {
                            // The current user is not in the backup (or is inactive there): back to sign in.
                            app.toasts.show(L10n.str(R.string.settings_restore_done_sign_in), ToastCenter.Style.Info)
                        }
                    }
                }) { Text(stringResource(R.string.settings_restore_confirm), color = Tokens.colors.danger) }
            },
            dismissButton = { TextButton({ pendingRestore = null }) { Text(stringResource(R.string.common_cancel)) } },
        )
    }

    if (confirmErase) {
        AlertDialog(
            onDismissRequest = { confirmErase = false },
            icon = { Icon(Icons.Filled.Delete, null, tint = Tokens.colors.danger) },
            title = { Text(stringResource(R.string.settings_erase_title)) },
            text = { Text(stringResource(R.string.settings_erase_message)) },
            confirmButton = { TextButton({ confirmErase = false; confirmEraseFinal = true }) { Text(stringResource(R.string.settings_continue), color = Tokens.colors.danger) } },
            dismissButton = { TextButton({ confirmErase = false }) { Text(stringResource(R.string.common_cancel)) } },
        )
    }

    if (confirmEraseFinal) {
        EraseFinalDialog(onDismiss = { confirmEraseFinal = false }) {
            confirmEraseFinal = false
            actions.run {
                // A full reset also unlinks the device from the cloud (and frees its seat).
                app.sync.forget()
                eraseAllData(app.db, app.images)
                app.settings.setDemoSeeded(false)
                // Toast first: signing out disposes this screen (and its scope) on the way to onboarding.
                app.toasts.show(L10n.str(R.string.settings_erased), ToastCenter.Style.Info)
                app.session.signOut()
            }
        }
    }
}

private class PendingRestore(val bytes: ByteArray, val summary: BackupService.Summary) {
    fun message(): String {
        val date = summary.exportedAt?.let { Fmt.date(it.atZone(ZoneId.systemDefault()).toLocalDate()) } ?: L10n.str(R.string.settings_unknown_date)
        val counts = summary.items.filter { it.value > 0 }.joinToString(", ") { L10n.plural(it.plural, it.value, it.value) }
        return L10n.str(R.string.settings_restore_message, date, summary.appVersion ?: "?", counts.ifEmpty { L10n.str(R.string.settings_no_records) })
    }
}

// Sections

/** Cloud link: company, licence, last sync, manual "Sincronizar", connect / disconnect. */
@Composable
private fun CloudSection(isAdmin: Boolean) {
    val app = LocalApp.current
    val status by app.sync.status.collectAsState()
    val account = status.account
    val c = Tokens.colors
    var connect by remember { mutableStateOf(false) }
    var confirmDisconnect by remember { mutableStateOf(false) }

    SettingsSection(
        stringResource(R.string.settings_cloud),
        stringResource(if (status.connected) R.string.settings_cloud_footer_connected else R.string.settings_cloud_footer_offline),
    ) {
        if (status.connected) {
            InfoLine(stringResource(R.string.settings_company), Icons.Filled.Apartment) { Text(account.tenantName ?: "—", color = c.secondary) }
            InfoLine(stringResource(R.string.settings_licence), Icons.Filled.WorkspacePremium) {
                val (label, tint) = when (account.licenceStatus) {
                    "expired" -> R.string.settings_licence_expired to c.danger
                    "suspended" -> R.string.settings_licence_suspended to c.danger
                    else -> R.string.settings_licence_active to c.success
                }
                Pill("${stringResource(planTitle(account.plan))} · ${stringResource(label)}", tint)
            }
            account.email?.let { email -> InfoLine(stringResource(R.string.settings_account_line), Icons.Filled.Badge) { Text(email, color = c.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis) } }
            InfoLine(stringResource(R.string.settings_last_sync), Icons.Filled.CloudDone) {
                Text(account.lastSyncAt?.let(::formatSyncTime) ?: stringResource(R.string.settings_never), color = c.secondary)
            }
            if (status.pending > 0) {
                InfoLine(stringResource(R.string.settings_pending_changes), Icons.Filled.CloudUpload) { Text(Fmt.int(status.pending), color = c.warning) }
            }
            account.lastError?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = c.danger) }
            HorizontalDivider(color = c.stroke)
            ActionRow(
                stringResource(if (status.running) R.string.settings_syncing else R.string.common_sync_now),
                stringResource(R.string.settings_sync_detail),
                Icons.Filled.Sync, c.brand,
            ) { if (!status.running) app.scope.launch { app.sync.syncNow(manual = true) } }
            if (isAdmin) {
                HorizontalDivider(color = c.stroke)
                ActionRow(stringResource(R.string.settings_disconnect_device), stringResource(R.string.settings_disconnect_device_detail), Icons.Filled.CloudOff, c.danger) {
                    confirmDisconnect = true
                }
            }
        } else {
            if (account.tenantId != null) {
                Text(
                    account.lastError ?: account.tenantName?.let { stringResource(R.string.settings_disconnected_from, it) } ?: stringResource(R.string.settings_disconnected),
                    style = MaterialTheme.typography.bodyMedium, color = c.secondary,
                )
            }
            ActionRow(stringResource(R.string.cloud_connect_licence), stringResource(R.string.settings_connect_detail), Icons.Filled.Cloud, c.brand) { connect = true }
        }
    }

    if (connect) CloudSignInDialog(onDismiss = { connect = false }, presetEmail = account.email.orEmpty())
    if (confirmDisconnect) {
        AlertDialog(
            onDismissRequest = { confirmDisconnect = false },
            title = { Text(stringResource(R.string.settings_disconnect_title)) },
            text = {
                Text(
                    if (status.pending > 0) pluralStringResource(R.plurals.settings_disconnect_pending, status.pending, Fmt.int(status.pending))
                    else stringResource(R.string.settings_disconnect_message),
                )
            },
            confirmButton = {
                TextButton({
                    confirmDisconnect = false
                    app.scope.launch { app.sync.signOutCloud(); app.toasts.show(L10n.str(R.string.settings_disconnected_toast), ToastCenter.Style.Info) }
                }) { Text(stringResource(R.string.settings_disconnect), color = c.danger) }
            },
            dismissButton = { TextButton({ confirmDisconnect = false }) { Text(stringResource(R.string.common_cancel)) } },
        )
    }
}

// Plan ids are the server's raw values; only their display name is localized.
private fun planTitle(plan: String?) = when (plan) {
    "web" -> R.string.settings_plan_web
    "planta" -> R.string.settings_plan_plant
    "multiplanta" -> R.string.settings_plan_multiplant
    "empresa" -> R.string.settings_plan_enterprise
    else -> R.string.settings_plan
}

private fun formatSyncTime(epochMillis: Long): String {
    val time = java.time.Instant.ofEpochMilli(epochMillis).atZone(ZoneId.systemDefault())
    val clock = time.toLocalTime().format(java.time.format.DateTimeFormatter.ofLocalizedTime(java.time.format.FormatStyle.SHORT).withLocale(Fmt.locale))
    return if (time.toLocalDate() == java.time.LocalDate.now()) L10n.str(R.string.settings_today_at, clock)
    else L10n.str(R.string.settings_day_at, Fmt.shortDate(time.toLocalDate()), clock)
}

/** In-app language picker; Android 13+ also offers it in the system's per-app language setting. */
@Composable
private fun LanguageSection() {
    val context = LocalContext.current
    val current = remember { L10n.language(context) }
    val options = listOf(
        AppLanguage.System to stringResource(R.string.settings_language_system),
        AppLanguage.Spanish to stringResource(R.string.settings_language_es),
        AppLanguage.English to stringResource(R.string.settings_language_en),
        AppLanguage.Portuguese to stringResource(R.string.settings_language_pt),
    )
    SettingsSection(stringResource(R.string.settings_language), stringResource(R.string.settings_language_footer)) {
        Column(Modifier.selectableGroup()) {
            options.forEach { (language, label) ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                        .selectable(selected = language == current, role = Role.RadioButton) {
                            context.findActivity()?.let { L10n.apply(it, language) }
                        }
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    RadioButton(selected = language == current, onClick = null)
                    Text(label, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
    }
}

private tailrec fun android.content.Context.findActivity(): android.app.Activity? = when (this) {
    is android.app.Activity -> this
    is android.content.ContextWrapper -> baseContext.findActivity()
    else -> null
}

@Composable
private fun SettingsSection(title: String, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = MaterialTheme.typography.labelLarge, color = Tokens.colors.secondary, modifier = Modifier.padding(start = 6.dp))
        TramaCard(padding = 18.dp, content = content)
        if (footer != null) Text(footer, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, modifier = Modifier.padding(horizontal = 6.dp))
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AccountSection(user: UserEntity?, plantName: String?, onChangePassword: () -> Unit) {
    val app = LocalApp.current
    SettingsSection(stringResource(R.string.settings_account)) {
        if (user != null) {
            Row(
                Modifier.semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Avatar(user.fullName, app.images.file(user.avatarFile), 60.dp)
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(user.fullName, style = MaterialTheme.typography.titleLarge)
                    Text(user.email, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Pill(stringResource(user.roleValue.titleRes), Tokens.colors.brand, Icons.Filled.Badge)
                        if (plantName != null) Pill(plantName, Tokens.colors.info, Icons.Filled.Apartment)
                    }
                }
            }
            HorizontalDivider(color = Tokens.colors.stroke)
        }
        ActionRow(stringResource(R.string.settings_change_password), null, Icons.Filled.Key, Tokens.colors.brand, onChangePassword)
    }
}

@Composable
private fun PreferencesSection(isAdmin: Boolean) {
    val app = LocalApp.current
    val actions = rememberActions()
    val urgency by app.settings.urgencyWindowDays.collectAsState(initial = null)
    val company by app.settings.companyName.collectAsState(initial = null)
    var companyText by rememberSaveable { mutableStateOf<String?>(null) }
    LaunchedEffect(company) { if (companyText == null && company != null) companyText = company }

    SettingsSection(
        stringResource(R.string.settings_preferences),
        stringResource(R.string.settings_urgency_footer),
    ) {
        if (isAdmin) {
            TramaField(
                companyText.orEmpty(),
                { text -> companyText = text; actions.run { app.settings.setCompanyName(text) } },
                stringResource(R.string.settings_company_name), leading = Icons.Filled.Apartment,
            )
        }
        val days = urgency ?: 7
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.Warning, null, tint = Tokens.colors.brand, modifier = Modifier.size(20.dp))
            Text(stringResource(R.string.settings_urgency_window), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            val daysLabel = pluralStringResource(R.plurals.settings_days, days, days)
            val daysDescription = stringResource(R.string.settings_urgency_window_value, daysLabel)
            Text(
                daysLabel, color = Tokens.colors.secondary,
                modifier = Modifier.semantics { contentDescription = daysDescription },
            )
            Row(Modifier.clip(Tokens.chipShape).background(Tokens.colors.ink.copy(alpha = 0.05f))) {
                IconButton({ actions.run { app.settings.setUrgencyWindowDays(days - 1) } }, enabled = days > 1) {
                    Icon(Icons.Filled.Remove, stringResource(R.string.settings_urgency_decrease), tint = Tokens.colors.brand)
                }
                IconButton({ actions.run { app.settings.setUrgencyWindowDays(days + 1) } }, enabled = days < 30) {
                    Icon(Icons.Filled.Add, stringResource(R.string.settings_urgency_increase), tint = Tokens.colors.brand)
                }
            }
        }
    }
}

@Composable
private fun DataSection(isAdmin: Boolean, onExport: () -> Unit, onRestore: () -> Unit, onDemo: () -> Unit, onErase: () -> Unit) {
    val app = LocalApp.current
    val demoSeeded by app.settings.demoSeeded.collectAsState(initial = false)
    val c = Tokens.colors
    SettingsSection(
        stringResource(R.string.settings_data),
        if (isAdmin) stringResource(R.string.settings_data_footer) else null,
    ) {
        if (isAdmin) {
            ActionRow(stringResource(R.string.settings_export), stringResource(R.string.settings_export_detail), Icons.Filled.FileUpload, c.brand, onExport)
            HorizontalDivider(color = c.stroke)
            ActionRow(stringResource(R.string.settings_restore), stringResource(R.string.settings_restore_detail), Icons.Filled.Restore, c.warning, onRestore)
            HorizontalDivider(color = c.stroke)
            ActionRow(
                stringResource(R.string.settings_demo),
                stringResource(if (demoSeeded) R.string.settings_demo_detail_loaded else R.string.settings_demo_detail),
                Icons.Filled.AutoAwesome, c.thread, onDemo,
            )
            HorizontalDivider(color = c.stroke)
            ActionRow(stringResource(R.string.settings_erase), stringResource(R.string.settings_erase_detail), Icons.Filled.Delete, c.danger, onErase)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Filled.Lock, null, tint = c.secondary, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.settings_data_admin_only), style = MaterialTheme.typography.bodyMedium, color = c.secondary)
            }
        }
    }
}

@Composable
private fun AboutSection() {
    val app = LocalApp.current
    val context = LocalContext.current
    val online = rememberIsOnline()
    val c = Tokens.colors
    val inMemory = stringResource(R.string.settings_storage_in_memory)
    val storage = remember(inMemory) {
        app.db.openHelper.databaseName?.let { context.getDatabasePath(it).path } ?: inMemory
    }
    SettingsSection(stringResource(R.string.settings_about)) {
        InfoLine(stringResource(R.string.settings_version), Icons.Filled.Info) { Text(BackupService.appVersion, color = c.secondary) }
        InfoLine(stringResource(R.string.settings_connection), if (online) Icons.Filled.Wifi else Icons.Filled.WifiOff) {
            Text(stringResource(if (online) R.string.settings_online else R.string.settings_offline), color = if (online) c.success else c.warning)
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Filled.CloudOff, null, tint = c.brand, modifier = Modifier.size(20.dp))
                Text(stringResource(R.string.settings_works_offline), style = MaterialTheme.typography.titleSmall)
            }
            Text(
                stringResource(R.string.settings_works_offline_detail),
                style = MaterialTheme.typography.bodySmall, color = c.secondary,
            )
        }
        InfoLine(stringResource(R.string.settings_storage), Icons.Filled.Storage) {
            Text(
                storage, style = MaterialTheme.typography.bodySmall, fontFamily = FontFamily.Monospace, color = c.secondary,
                maxLines = 2, overflow = TextOverflow.StartEllipsis,
            )
        }
    }
}

@Composable
private fun InfoLine(label: String, icon: ImageVector, value: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, null, tint = Tokens.colors.brand, modifier = Modifier.size(20.dp))
        Text(label, style = MaterialTheme.typography.bodyLarge)
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) { value() }
    }
}

@Composable
private fun ActionRow(title: String, subtitle: String?, icon: ImageVector, tint: Color, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
            .clickable(role = Role.Button, onClick = onClick)
            .semantics(mergeDescendants = true) {}
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(34.dp).clip(RoundedCornerShape(10.dp)).background(tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Tokens.colors.secondary.copy(alpha = 0.5f))
    }
}

// Dialogs

@Composable
private fun ChangePasswordDialog(user: UserEntity, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val actions = rememberActions()
    val scope = rememberCoroutineScope()
    var current by remember { mutableStateOf("") }
    var new by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val canSave = current.isNotEmpty() && new.isNotEmpty() && confirm.isNotEmpty() && !busy

    fun save() {
        busy = true
        scope.launch {
            // PBKDF2 with 120k iterations: keep it off the main thread.
            val validCurrent = withContext(Dispatchers.Default) { PasswordHasher.verify(current, user.passwordHash, user.passwordSalt) }
            error = when {
                !validCurrent -> L10n.str(R.string.settings_password_wrong_current)
                new.length < 6 -> AuthError.WeakPassword.message
                new != confirm -> L10n.str(R.string.settings_password_mismatch)
                new == current -> L10n.str(R.string.settings_password_same)
                else -> null
            }
            if (error != null) { busy = false; return@launch }
            val updated = withContext(Dispatchers.Default) { Session.withPassword(user, new) }
            actions.run(success = L10n.str(R.string.settings_password_updated), onDone = onDismiss) {
                app.db.dao().upsert(updated)
                app.session.adopt(updated)
            }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.settings_change_password)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                PasswordField(current, { current = it; error = null }, stringResource(R.string.settings_password_current))
                PasswordField(new, { new = it; error = null }, stringResource(R.string.settings_password_new))
                PasswordField(confirm, { confirm = it; error = null }, stringResource(R.string.settings_password_confirm))
                error?.let {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon(Icons.Filled.Error, null, tint = Tokens.colors.danger, modifier = Modifier.size(16.dp))
                        Text(it, color = Tokens.colors.danger, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        },
        confirmButton = { TextButton(::save, enabled = canSave) { Text(stringResource(R.string.common_save)) } },
        dismissButton = { TextButton(onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}

@Composable
private fun PasswordField(value: String, onChange: (String) -> Unit, label: String) {
    OutlinedTextField(
        value, onChange, Modifier.fillMaxWidth(), label = { Text(label) }, singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = Tokens.colors.stroke),
    )
}

@Composable
private fun EraseFinalDialog(onDismiss: () -> Unit, onConfirm: () -> Unit) {
    var text by remember { mutableStateOf("") }
    // The confirmation word is localized ("BORRAR", "DELETE", "APAGAR").
    val word = stringResource(R.string.settings_erase_word)
    val armed = text.trim().uppercase(Fmt.locale) == word.uppercase(Fmt.locale)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.settings_erase_final_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.settings_erase_final_message, word))
                OutlinedTextField(
                    text, { text = it }, Modifier.fillMaxWidth(), placeholder = { Text(word) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                    shape = RoundedCornerShape(14.dp),
                )
            }
        },
        confirmButton = { TextButton(onConfirm, enabled = armed) { Text(stringResource(R.string.settings_erase_all), color = if (armed) Tokens.colors.danger else Tokens.colors.secondary) } },
        dismissButton = { TextButton(onDismiss) { Text(stringResource(R.string.common_cancel)) } },
    )
}
