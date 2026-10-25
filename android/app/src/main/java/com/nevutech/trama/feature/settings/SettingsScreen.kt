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
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Restore
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
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
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.ToastCenter
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.app.rememberIsOnline
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.ZoneId

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
        actions.run(success = "Respaldo guardado") {
            val bytes = BackupService.export(app.db, app.images)
            withContext(Dispatchers.IO) {
                context.contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) } ?: error("No se pudo escribir el archivo.")
            }
        }
    }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        actions.run {
            val bytes = withContext(Dispatchers.IO) {
                context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: error("No se pudo leer el archivo.")
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
                if (LocalConfiguration.current.screenWidthDp >= 600) Text("Ajustes", style = MaterialTheme.typography.headlineMedium)
                AccountSection(user, graph.plant(user?.plantId)?.name) { showPassword = true }
                PreferencesSection(isAdmin)
                DataSection(
                    isAdmin = isAdmin,
                    onExport = { exporter.launch(BackupService.filename()) },
                    onRestore = { importer.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) },
                    onDemo = {
                        val operational = graph.plants.size + graph.orders.size + graph.clients.size + graph.styles.size
                        if (operational > 0) {
                            app.toasts.show("Ya hay datos en este dispositivo. Bórralos primero para cargar los datos de ejemplo.", ToastCenter.Style.Info)
                        } else {
                            actions.run(success = "Datos de ejemplo cargados. Cuentas demo con contraseña ${DemoSeeder.DEMO_PASSWORD}.") {
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
                    Text("Cerrar sesión", color = Tokens.colors.danger, modifier = Modifier.padding(start = 8.dp))
                }
            }
        }
    }

    if (showPassword) user?.let { ChangePasswordDialog(it) { showPassword = false } }

    if (confirmSignOut) {
        AlertDialog(
            onDismissRequest = { confirmSignOut = false },
            title = { Text("¿Cerrar sesión?") },
            text = { Text("Tus datos se quedan guardados en este dispositivo.") },
            confirmButton = {
                TextButton({ confirmSignOut = false; actions.run { app.session.signOut() } }) { Text("Cerrar sesión", color = Tokens.colors.danger) }
            },
            dismissButton = { TextButton({ confirmSignOut = false }) { Text("Cancelar") } },
        )
    }

    pendingRestore?.let { pending ->
        AlertDialog(
            onDismissRequest = { pendingRestore = null },
            icon = { Icon(Icons.Filled.Warning, null, tint = Tokens.colors.warning) },
            title = { Text("¿Restaurar respaldo?") },
            text = { Text(pending.message) },
            confirmButton = {
                TextButton({
                    pendingRestore = null
                    actions.run {
                        withContext(Dispatchers.Default) { BackupService.restore(pending.bytes, app.db, app.images) }
                        app.session.restore()
                        if (app.session.user.value != null) {
                            app.toasts.show("Respaldo restaurado: ${Fmt.int(pending.summary.total)} registros")
                        } else {
                            // The current user is not in the backup (or is inactive there): back to sign in.
                            app.toasts.show("Respaldo restaurado. Inicia sesión con una cuenta del respaldo.", ToastCenter.Style.Info)
                        }
                    }
                }) { Text("Reemplazar todos los datos", color = Tokens.colors.danger) }
            },
            dismissButton = { TextButton({ pendingRestore = null }) { Text("Cancelar") } },
        )
    }

    if (confirmErase) {
        AlertDialog(
            onDismissRequest = { confirmErase = false },
            icon = { Icon(Icons.Filled.Delete, null, tint = Tokens.colors.danger) },
            title = { Text("¿Borrar todos los datos?") },
            text = { Text("Se eliminarán plantas, cortes, reportes, catálogos y usuarios de este dispositivo. Exporta un respaldo antes si lo necesitas.") },
            confirmButton = { TextButton({ confirmErase = false; confirmEraseFinal = true }) { Text("Continuar", color = Tokens.colors.danger) } },
            dismissButton = { TextButton({ confirmErase = false }) { Text("Cancelar") } },
        )
    }

    if (confirmEraseFinal) {
        EraseFinalDialog(onDismiss = { confirmEraseFinal = false }) {
            confirmEraseFinal = false
            actions.run {
                eraseAllData(app.db, app.images)
                app.settings.setDemoSeeded(false)
                // Toast first: signing out disposes this screen (and its scope) on the way to onboarding.
                app.toasts.show("Se borraron todos los datos", ToastCenter.Style.Info)
                app.session.signOut()
            }
        }
    }
}

private class PendingRestore(val bytes: ByteArray, val summary: BackupService.Summary) {
    val message: String
        get() {
            val date = summary.exportedAt?.let { Fmt.date(it.atZone(ZoneId.systemDefault()).toLocalDate()) } ?: "fecha desconocida"
            val counts = summary.counts.filter { it.second > 0 }.joinToString(", ") { "${it.second} ${it.first.lowercase()}" }
            return "Respaldo del $date (Trama ${summary.appVersion ?: "?"}): ${counts.ifEmpty { "sin registros" }}. " +
                "Se borrarán todos los datos actuales de este dispositivo."
        }
}

// Sections

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
    SettingsSection("Cuenta") {
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
                        Pill(user.roleValue.title, Tokens.colors.brand, Icons.Filled.Badge)
                        if (plantName != null) Pill(plantName, Tokens.colors.info, Icons.Filled.Apartment)
                    }
                }
            }
            HorizontalDivider(color = Tokens.colors.stroke)
        }
        ActionRow("Cambiar contraseña", null, Icons.Filled.Key, Tokens.colors.brand, onChangePassword)
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
        "Preferencias",
        "Un envío es urgente si tiene prendas por enviar y la fecha del cliente cae dentro de esta ventana, o ya venció.",
    ) {
        if (isAdmin) {
            TramaField(
                companyText.orEmpty(),
                { text -> companyText = text; actions.run { app.settings.setCompanyName(text) } },
                "Nombre de la empresa", leading = Icons.Filled.Apartment,
            )
        }
        val days = urgency ?: 7
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.Warning, null, tint = Tokens.colors.brand, modifier = Modifier.size(20.dp))
            Text("Ventana de urgencia", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            Text(
                "$days ${if (days == 1) "día" else "días"}", color = Tokens.colors.secondary,
                modifier = Modifier.semantics { contentDescription = "Ventana de urgencia: $days días" },
            )
            Row(Modifier.clip(Tokens.chipShape).background(Tokens.colors.ink.copy(alpha = 0.05f))) {
                IconButton({ actions.run { app.settings.setUrgencyWindowDays(days - 1) } }, enabled = days > 1) {
                    Icon(Icons.Filled.Remove, "Reducir ventana", tint = Tokens.colors.brand)
                }
                IconButton({ actions.run { app.settings.setUrgencyWindowDays(days + 1) } }, enabled = days < 30) {
                    Icon(Icons.Filled.Add, "Ampliar ventana", tint = Tokens.colors.brand)
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
        "Datos",
        if (isAdmin) "Los respaldos incluyen las contraseñas cifradas de los usuarios. Guárdalos en un lugar seguro." else null,
    ) {
        if (isAdmin) {
            ActionRow("Exportar respaldo", "Archivo JSON con todos los datos e imágenes", Icons.Filled.FileUpload, c.brand, onExport)
            HorizontalDivider(color = c.stroke)
            ActionRow("Restaurar respaldo", "Reemplaza los datos de este dispositivo", Icons.Filled.Restore, c.warning, onRestore)
            HorizontalDivider(color = c.stroke)
            ActionRow(
                "Cargar datos de ejemplo",
                if (demoSeeded) "Ya cargados en este dispositivo" else "Solo si no hay datos operativos",
                Icons.Filled.AutoAwesome, c.thread, onDemo,
            )
            HorizontalDivider(color = c.stroke)
            ActionRow("Borrar todos los datos", "Regresa Trama a su configuración inicial", Icons.Filled.Delete, c.danger, onErase)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Filled.Lock, null, tint = c.secondary, modifier = Modifier.size(18.dp))
                Text("Solo el administrador puede respaldar, restaurar o borrar los datos.", style = MaterialTheme.typography.bodyMedium, color = c.secondary)
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
    val storage = remember {
        app.db.openHelper.databaseName?.let { context.getDatabasePath(it).path } ?: "En memoria (demostración)"
    }
    SettingsSection("Acerca de") {
        InfoLine("Versión", Icons.Filled.Info) { Text(BackupService.appVersion, color = c.secondary) }
        InfoLine("Conexión", if (online) Icons.Filled.Wifi else Icons.Filled.WifiOff) {
            Text(if (online) "En línea" else "Sin conexión", color = if (online) c.success else c.warning)
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Filled.CloudOff, null, tint = c.brand, modifier = Modifier.size(20.dp))
                Text("Funciona sin conexión", style = MaterialTheme.typography.titleSmall)
            }
            Text(
                "Todos los datos viven en este dispositivo. Puedes registrar cortes, asignaciones y reportes sin internet; Trama nunca necesita conexión para operar.",
                style = MaterialTheme.typography.bodySmall, color = c.secondary,
            )
        }
        InfoLine("Almacenamiento", Icons.Filled.Storage) {
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
                !validCurrent -> "La contraseña actual no es correcta."
                new.length < 6 -> AuthError.WeakPassword.message
                new != confirm -> "Las contraseñas nuevas no coinciden."
                new == current -> "La nueva contraseña debe ser distinta a la actual."
                else -> null
            }
            if (error != null) { busy = false; return@launch }
            val updated = withContext(Dispatchers.Default) { Session.withPassword(user, new) }
            actions.run(success = "Contraseña actualizada", onDone = onDismiss) {
                app.db.dao().upsert(updated)
                app.session.adopt(updated)
            }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Cambiar contraseña") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                PasswordField(current, { current = it; error = null }, "Contraseña actual")
                PasswordField(new, { new = it; error = null }, "Nueva contraseña (mín. 6 caracteres)")
                PasswordField(confirm, { confirm = it; error = null }, "Confirmar nueva contraseña")
                error?.let {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon(Icons.Filled.Error, null, tint = Tokens.colors.danger, modifier = Modifier.size(16.dp))
                        Text(it, color = Tokens.colors.danger, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        },
        confirmButton = { TextButton(::save, enabled = canSave) { Text("Guardar") } },
        dismissButton = { TextButton(onDismiss) { Text("Cancelar") } },
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
    val armed = text.trim().uppercase() == "BORRAR"
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Confirmación final") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Escribe BORRAR para eliminar todos los datos. Esta acción no se puede deshacer.")
                OutlinedTextField(
                    text, { text = it }, Modifier.fillMaxWidth(), placeholder = { Text("BORRAR") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                    shape = RoundedCornerShape(14.dp),
                )
            }
        },
        confirmButton = { TextButton(onConfirm, enabled = armed) { Text("Borrar todo", color = if (armed) Tokens.colors.danger else Tokens.colors.secondary) } },
        dismissButton = { TextButton(onDismiss) { Text("Cancelar") } },
    )
}
