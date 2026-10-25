package com.nevutech.trama.feature.users

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.HowToReg
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material.icons.outlined.PersonSearch
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.ImageEdit
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.data.UserDraft
import com.nevutech.trama.core.data.UserEntity
import com.nevutech.trama.core.data.fullName
import com.nevutech.trama.core.data.roleValue
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.KpiTile
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.feature.clients.AdaptiveRows
import com.nevutech.trama.feature.clients.CatalogGrid
import com.nevutech.trama.feature.clients.ConfirmDeleteDialog
import com.nevutech.trama.feature.clients.FormSection
import com.nevutech.trama.feature.clients.FormSheet
import com.nevutech.trama.feature.clients.MenuItem
import com.nevutech.trama.feature.clients.NoResults
import com.nevutech.trama.feature.clients.PickerField
import com.nevutech.trama.feature.clients.SecureField
import com.nevutech.trama.feature.clients.Segmented
import com.nevutech.trama.feature.clients.WithContextMenu
import com.nevutech.trama.feature.clients.cardClick
import com.nevutech.trama.feature.clients.catalogMatches
import com.nevutech.trama.feature.clients.fullSpan
import com.nevutech.trama.feature.clients.icon
import com.nevutech.trama.feature.clients.rememberCatalog
import com.nevutech.trama.feature.clients.rememberToasts
import com.nevutech.trama.feature.styles.PhotoField
import com.nevutech.trama.feature.styles.PhotoPreview
import java.io.File

private enum class UserFilter(val title: String) { Active("Activos"), Inactive("Inactivos"), All("Todos") }

/** Sheet target: a new user (null) or an existing one. */
private data class UserEditorTarget(val user: UserEntity?)

/** User administration (admins only). */
@Composable
fun UsersScreen() {
    val app = LocalApp.current
    val me by app.session.user.collectAsState()
    if (me?.roleValue != Role.Admin) {
        TramaScreen { EmptyState("Solo administradores", "Pide a un administrador que gestione los usuarios.", Icons.Filled.Lock) }
        return
    }
    val graph by rememberGraph()
    val actions = rememberActions()
    val catalog = rememberCatalog()
    var filter by rememberSaveable { mutableStateOf(UserFilter.Active) }
    var roleFilter by rememberSaveable { mutableStateOf<Role?>(null) }
    var search by rememberSaveable { mutableStateOf("") }
    var editor by remember { mutableStateOf<UserEditorTarget?>(null) }
    var resetting by remember { mutableStateOf<UserEntity?>(null) }
    var pendingDelete by remember { mutableStateOf<UserEntity?>(null) }

    val users = graph.users.sortedWith(compareBy({ it.firstName.lowercase() }, { it.lastName.lowercase() }))
    val meId = me?.id
    fun count(option: UserFilter) = when (option) {
        UserFilter.Active -> users.count { it.isActive }
        UserFilter.Inactive -> users.count { !it.isActive }
        UserFilter.All -> users.size
    }
    val visible = users.filter { u ->
        val state = when (filter) { UserFilter.Active -> u.isActive; UserFilter.Inactive -> !u.isActive; UserFilter.All -> true }
        state && (roleFilter == null || u.roleValue == roleFilter) &&
            catalogMatches(search, listOf(u.fullName, u.email, u.phone, u.roleValue.title, graph.plant(u.plantId)?.name))
    }

    fun setActive(user: UserEntity, active: Boolean) = actions.run(
        success = if (active) "${user.fullName} puede volver a ingresar" else "${user.fullName} fue desactivado",
    ) { catalog.setActive(user, active, meId) }

    TramaScreen {
        CatalogGrid("Usuarios", search, { search = it }, "Buscar por nombre, correo o puesto", "Nuevo usuario", { editor = UserEditorTarget(null) }) {
            fullSpan {
                AdaptiveRows(Role.entries, minWidth = 150.dp, spacing = 18.dp) { role ->
                    KpiTile(
                        role.title, Fmt.int(users.count { it.roleValue == role && it.isActive }), role.icon, Tokens.accent(role.raw),
                        footnote = if (roleFilter == role) "Filtrando · toca para quitar" else null,
                        onClick = { roleFilter = if (roleFilter == role) null else role },
                    )
                }
            }
            fullSpan {
                Segmented(UserFilter.entries, filter, { "${it.title} (${count(it)})" }, { filter = it }, Modifier.widthIn(max = 480.dp).fillMaxWidth())
            }
            when {
                visible.isEmpty() && search.isBlank() -> fullSpan {
                    EmptyState("Sin usuarios ${filter.title.lowercase()}", "Cambia el filtro para ver a otros usuarios.", Icons.Outlined.PersonSearch)
                }
                visible.isEmpty() -> fullSpan { NoResults(search) }
                else -> items(visible.size, key = { visible[it].id }) { i ->
                    val user = visible[i]
                    val isCurrent = user.id == meId
                    WithContextMenu(menu = { close ->
                        MenuItem("Editar", Icons.Filled.Edit) { close(); editor = UserEditorTarget(user) }
                        MenuItem("Restablecer contraseña", Icons.Filled.Key) { close(); resetting = user }
                        if (user.isActive) MenuItem("Desactivar", Icons.Filled.PersonOff, enabled = !isCurrent) { close(); setActive(user, false) }
                        else MenuItem("Activar", Icons.Filled.HowToReg) { close(); setActive(user, true) }
                        HorizontalDivider()
                        MenuItem("Eliminar", Icons.Filled.Delete, destructive = true, enabled = !isCurrent) { close(); pendingDelete = user }
                    }) { open ->
                        UserCard(user, graph.plant(user.plantId), isCurrent, Modifier.cardClick({ editor = UserEditorTarget(user) }, open)) { setActive(user, it) }
                    }
                }
            }
        }
    }

    editor?.let { target -> UserEditorSheet(target.user, meId, graph.plants) { editor = null } }
    resetting?.let { user -> PasswordResetSheet(user) { resetting = null } }
    pendingDelete?.let { user ->
        ConfirmDeleteDialog(
            "¿Eliminar a ${user.fullName}?", "Perderá el acceso a Trama. Si solo quieres pausar su acceso, desactívalo.",
            onConfirm = { actions.run(success = "Usuario «${user.fullName}» eliminado") { catalog.deleteUser(user, meId) } },
            onDismiss = { pendingDelete = null },
        )
    }
}

@Composable
private fun UserCard(user: UserEntity, plant: PlantEntity?, isCurrent: Boolean, modifier: Modifier, setActive: (Boolean) -> Unit) {
    val images = LocalApp.current.images
    val role = user.roleValue
    TramaCard(modifier.fillMaxWidth().alpha(if (user.isActive) 1f else 0.75f)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Avatar(user.fullName, images.file(user.avatarFile), size = 58.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(user.fullName, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (isCurrent) Pill("Tú", Tokens.colors.brand)
                }
                Pill(role.title, Tokens.colors.brand, role.icon)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (role == Role.PlantManager) {
                InfoLine(Icons.Filled.Apartment, plant?.name ?: "Sin planta asignada", if (plant == null) Tokens.colors.danger else Tokens.colors.ink)
            }
            InfoLine(Icons.Filled.Email, user.email)
            if (user.phone.isNotBlank()) InfoLine(Icons.Filled.Phone, user.phone)
        }
        HorizontalDivider(color = Tokens.colors.stroke)
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (user.isActive) InfoLine(Icons.Filled.VerifiedUser, "Con acceso", Tokens.colors.success)
            else InfoLine(Icons.Filled.Lock, "Sin acceso a la app", Tokens.colors.warning)
            Spacer(Modifier.weight(1f))
            Switch(
                user.isActive, setActive, enabled = !isCurrent,
                modifier = Modifier.semantics { contentDescription = if (user.isActive) "Usuario activo" else "Usuario inactivo" },
            )
        }
    }
}

@Composable
private fun InfoLine(icon: ImageVector, text: String, tint: Color = Tokens.colors.secondary) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp))
        Text(text, style = MaterialTheme.typography.bodyMedium, color = tint, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun UserEditorSheet(user: UserEntity?, meId: String?, plants: List<PlantEntity>, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val catalog = rememberCatalog()
    val actions = rememberActions()
    val toasts = rememberToasts()
    var draft by remember { mutableStateOf(user?.let(UserDraft::of) ?: UserDraft()) }
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    val isNew = user == null
    val isSelf = user != null && user.id == meId
    val currentAvatar: File? = app.images.file(user?.avatarFile)

    val passwordProblem = when {
        !isNew || password.isEmpty() -> null
        password.length < 6 -> "Al menos 6 caracteres."
        confirmation.isNotEmpty() && confirmation != password -> "Las contraseñas no coinciden."
        else -> null
    }
    val basics = draft.firstName.isNotBlank() && draft.email.isNotBlank() && (draft.role != Role.PlantManager || draft.plantId != null)
    val canSave = if (isNew) basics && password.length >= 6 && password == confirmation else basics

    FormSheet(
        if (isNew) "Nuevo usuario" else "Editar usuario", onDismiss, saveTitle = if (isNew) "Crear" else "Guardar", canSave = canSave,
        onSave = {
            actions.run(onDone = onDismiss) {
                if (user != null) {
                    catalog.updateUser(user, draft, meId)
                    toasts.show("Usuario actualizado")
                } else {
                    val created = catalog.createUser(draft, password)
                    toasts.show("Usuario «${created.fullName}» creado")
                }
            }
        },
    ) {
        FormSection("Perfil") {
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.CenterVertically) {
                val name = "${draft.firstName} ${draft.lastName}".trim().ifEmpty { "?" }
                when (val avatar = draft.avatar) {
                    is ImageEdit.Replace -> PhotoPreview(name, null, avatar, Modifier.size(72.dp), corner = 22.dp)
                    ImageEdit.Remove -> Avatar(name, null, size = 72.dp)
                    ImageEdit.Keep -> Avatar(name, currentAvatar, size = 72.dp)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    TramaField(draft.firstName, { draft = draft.copy(firstName = it) }, "Nombre")
                    TramaField(draft.lastName, { draft = draft.copy(lastName = it) }, "Apellido")
                }
            }
            PhotoField("Foto de perfil", currentAvatar, draft.avatar) { draft = draft.copy(avatar = it) }
        }
        FormSection("Contacto") {
            TramaField(draft.email, { draft = draft.copy(email = it) }, "Correo electrónico", keyboard = KeyboardType.Email)
            TramaField(draft.phone, { draft = draft.copy(phone = it) }, "Teléfono", keyboard = KeyboardType.Phone)
        }
        FormSection(
            "Puesto",
            footer = when {
                isSelf -> "No puedes cambiar tu propio puesto."
                draft.role == Role.PlantManager && draft.plantId == null -> "Un gerente de planta debe tener una planta asignada."
                draft.role == Role.PlantManager -> "Solo verá la producción de su planta."
                else -> null
            },
            footerColor = if (!isSelf && draft.role == Role.PlantManager && draft.plantId == null) Tokens.colors.danger else null,
        ) {
            PickerField("Puesto", Role.entries, draft.role, { it.title }, { draft = draft.copy(role = it) }, enabled = !isSelf)
            if (draft.role == Role.PlantManager) {
                val selected = plants.firstOrNull { it.id == draft.plantId }
                PickerField(
                    "Planta", listOf<PlantEntity?>(null) + plants, selected, { it?.name ?: "Elegir planta" }, { draft = draft.copy(plantId = it?.id) },
                    isError = selected == null,
                )
            }
        }
        if (isNew) {
            FormSection(
                "Contraseña",
                footer = passwordProblem ?: "Mínimo 6 caracteres. El usuario podrá ingresar sin conexión con ella.",
                footerColor = if (passwordProblem != null) Tokens.colors.danger else null,
            ) {
                SecureField(password, { password = it }, "Contraseña")
                SecureField(confirmation, { confirmation = it }, "Confirmar contraseña")
            }
        }
    }
}

@Composable
private fun PasswordResetSheet(user: UserEntity, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val catalog = rememberCatalog()
    val actions = rememberActions()
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    val problem = when {
        password.isNotEmpty() && password.length < 6 -> "Al menos 6 caracteres."
        confirmation.isNotEmpty() && confirmation != password -> "Las contraseñas no coinciden."
        else -> null
    }

    FormSheet(
        "Restablecer contraseña", onDismiss, saveTitle = "Restablecer", canSave = password.length >= 6 && password == confirmation,
        onSave = { actions.run(success = "Contraseña de ${user.fullName} restablecida", onDone = onDismiss) { catalog.resetPassword(user, password) } },
    ) {
        FormSection(null) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Avatar(user.fullName, app.images.file(user.avatarFile), size = 48.dp)
                Column {
                    Text(user.fullName, style = MaterialTheme.typography.titleMedium)
                    Text(user.email, style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
                }
            }
        }
        FormSection(
            null, footer = problem ?: "Comparte la nueva contraseña con el usuario en persona.",
            footerColor = if (problem != null) Tokens.colors.danger else null,
        ) {
            SecureField(password, { password = it }, "Nueva contraseña")
            SecureField(confirmation, { confirmation = it }, "Confirmar contraseña")
        }
    }
}
