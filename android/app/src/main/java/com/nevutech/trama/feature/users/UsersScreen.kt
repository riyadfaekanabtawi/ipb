package com.nevutech.trama.feature.users

import androidx.annotation.StringRes
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nevutech.trama.R
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
import com.nevutech.trama.core.l10n.L10n
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

private enum class UserFilter(@StringRes val titleRes: Int, @StringRes val emptyRes: Int) {
    Active(R.string.users_filter_active, R.string.users_empty_active),
    Inactive(R.string.users_filter_inactive, R.string.users_empty_inactive),
    All(R.string.common_all_masc, R.string.users_empty_all);

    val title: String get() = L10n.str(titleRes)
}

/** Sheet target: a new user (null) or an existing one. */
private data class UserEditorTarget(val user: UserEntity?)

/** User administration (admins only). */
@Composable
fun UsersScreen() {
    val app = LocalApp.current
    val me by app.session.user.collectAsState()
    if (me?.roleValue != Role.Admin) {
        TramaScreen { EmptyState(stringResource(R.string.users_admins_only), stringResource(R.string.users_admins_only_message), Icons.Filled.Lock) }
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
        success = L10n.str(if (active) R.string.users_activated else R.string.users_deactivated, user.fullName),
    ) { catalog.setActive(user, active, meId) }

    TramaScreen {
        CatalogGrid(stringResource(R.string.section_users), search, { search = it }, stringResource(R.string.users_search_hint), stringResource(R.string.users_new), { editor = UserEditorTarget(null) }) {
            fullSpan {
                AdaptiveRows(Role.entries, minWidth = 150.dp, spacing = 18.dp) { role ->
                    KpiTile(
                        stringResource(role.titleRes), Fmt.int(users.count { it.roleValue == role && it.isActive }), role.icon, Tokens.accent(role.raw),
                        footnote = if (roleFilter == role) stringResource(R.string.users_filtering_tap_to_clear) else null,
                        onClick = { roleFilter = if (roleFilter == role) null else role },
                    )
                }
            }
            fullSpan {
                Segmented(UserFilter.entries, filter, { L10n.str(R.string.users_filter_count, it.title, Fmt.int(count(it))) }, { filter = it }, Modifier.widthIn(max = 480.dp).fillMaxWidth())
            }
            when {
                visible.isEmpty() && search.isBlank() -> fullSpan {
                    EmptyState(stringResource(filter.emptyRes), stringResource(R.string.users_empty_message), Icons.Outlined.PersonSearch)
                }
                visible.isEmpty() -> fullSpan { NoResults(search) }
                else -> items(visible.size, key = { visible[it].id }) { i ->
                    val user = visible[i]
                    val isCurrent = user.id == meId
                    WithContextMenu(menu = { close ->
                        MenuItem(stringResource(R.string.common_edit), Icons.Filled.Edit) { close(); editor = UserEditorTarget(user) }
                        MenuItem(stringResource(R.string.users_reset_password), Icons.Filled.Key) { close(); resetting = user }
                        if (user.isActive) MenuItem(stringResource(R.string.users_deactivate), Icons.Filled.PersonOff, enabled = !isCurrent) { close(); setActive(user, false) }
                        else MenuItem(stringResource(R.string.users_activate), Icons.Filled.HowToReg) { close(); setActive(user, true) }
                        HorizontalDivider()
                        MenuItem(stringResource(R.string.common_delete), Icons.Filled.Delete, destructive = true, enabled = !isCurrent) { close(); pendingDelete = user }
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
            stringResource(R.string.users_delete_title, user.fullName), stringResource(R.string.users_delete_message),
            onConfirm = { actions.run(success = L10n.str(R.string.users_deleted, user.fullName)) { catalog.deleteUser(user, meId) } },
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
                    if (isCurrent) Pill(stringResource(R.string.users_you), Tokens.colors.brand)
                }
                Pill(stringResource(role.titleRes), Tokens.colors.brand, role.icon)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (role == Role.PlantManager) {
                InfoLine(Icons.Filled.Apartment, plant?.name ?: stringResource(R.string.users_no_plant), if (plant == null) Tokens.colors.danger else Tokens.colors.ink)
            }
            InfoLine(Icons.Filled.Email, user.email)
            if (user.phone.isNotBlank()) InfoLine(Icons.Filled.Phone, user.phone)
        }
        HorizontalDivider(color = Tokens.colors.stroke)
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (user.isActive) InfoLine(Icons.Filled.VerifiedUser, stringResource(R.string.users_has_access), Tokens.colors.success)
            else InfoLine(Icons.Filled.Lock, stringResource(R.string.users_no_access), Tokens.colors.warning)
            Spacer(Modifier.weight(1f))
            val stateDescription = stringResource(if (user.isActive) R.string.users_state_active else R.string.users_state_inactive)
            Switch(
                user.isActive, setActive, enabled = !isCurrent,
                modifier = Modifier.semantics { contentDescription = stateDescription },
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
        password.length < 6 -> stringResource(R.string.users_password_too_short)
        confirmation.isNotEmpty() && confirmation != password -> stringResource(R.string.users_password_mismatch)
        else -> null
    }
    val basics = draft.firstName.isNotBlank() && draft.email.isNotBlank() && (draft.role != Role.PlantManager || draft.plantId != null)
    val canSave = if (isNew) basics && password.length >= 6 && password == confirmation else basics

    FormSheet(
        stringResource(if (isNew) R.string.users_new else R.string.users_edit), onDismiss,
        saveTitle = stringResource(if (isNew) R.string.users_create else R.string.common_save), canSave = canSave,
        onSave = {
            actions.run(onDone = onDismiss) {
                if (user != null) {
                    catalog.updateUser(user, draft, meId)
                    toasts.show(L10n.str(R.string.users_updated))
                } else {
                    val created = catalog.createUser(draft, password)
                    toasts.show(L10n.str(R.string.users_created, created.fullName))
                }
            }
        },
    ) {
        FormSection(stringResource(R.string.users_profile)) {
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.CenterVertically) {
                val name = "${draft.firstName} ${draft.lastName}".trim().ifEmpty { "?" }
                when (val avatar = draft.avatar) {
                    is ImageEdit.Replace -> PhotoPreview(name, null, avatar, Modifier.size(72.dp), corner = 22.dp)
                    ImageEdit.Remove -> Avatar(name, null, size = 72.dp)
                    ImageEdit.Keep -> Avatar(name, currentAvatar, size = 72.dp)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    TramaField(draft.firstName, { draft = draft.copy(firstName = it) }, stringResource(R.string.users_first_name))
                    TramaField(draft.lastName, { draft = draft.copy(lastName = it) }, stringResource(R.string.users_last_name))
                }
            }
            PhotoField(stringResource(R.string.users_profile_photo), currentAvatar, draft.avatar) { draft = draft.copy(avatar = it) }
        }
        FormSection(stringResource(R.string.common_contact)) {
            TramaField(draft.email, { draft = draft.copy(email = it) }, stringResource(R.string.common_email), keyboard = KeyboardType.Email)
            TramaField(draft.phone, { draft = draft.copy(phone = it) }, stringResource(R.string.common_phone), keyboard = KeyboardType.Phone)
        }
        FormSection(
            stringResource(R.string.common_role),
            footer = when {
                isSelf -> stringResource(R.string.policy_cannot_change_own_role)
                draft.role == Role.PlantManager && draft.plantId == null -> stringResource(R.string.catalog_error_plant_required)
                draft.role == Role.PlantManager -> stringResource(R.string.users_plant_manager_scope)
                else -> null
            },
            footerColor = if (!isSelf && draft.role == Role.PlantManager && draft.plantId == null) Tokens.colors.danger else null,
        ) {
            PickerField(stringResource(R.string.common_role), Role.entries, draft.role, { it.title }, { draft = draft.copy(role = it) }, enabled = !isSelf)
            if (draft.role == Role.PlantManager) {
                val selected = plants.firstOrNull { it.id == draft.plantId }
                val choosePlant = stringResource(R.string.users_choose_plant)
                PickerField(
                    stringResource(R.string.common_plant), listOf<PlantEntity?>(null) + plants, selected, { it?.name ?: choosePlant }, { draft = draft.copy(plantId = it?.id) },
                    isError = selected == null,
                )
            }
        }
        if (isNew) {
            FormSection(
                stringResource(R.string.common_password),
                footer = passwordProblem ?: stringResource(R.string.users_password_footer),
                footerColor = if (passwordProblem != null) Tokens.colors.danger else null,
            ) {
                SecureField(password, { password = it }, stringResource(R.string.common_password))
                SecureField(confirmation, { confirmation = it }, stringResource(R.string.users_confirm_password))
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
        password.isNotEmpty() && password.length < 6 -> stringResource(R.string.users_password_too_short)
        confirmation.isNotEmpty() && confirmation != password -> stringResource(R.string.users_password_mismatch)
        else -> null
    }

    FormSheet(
        stringResource(R.string.users_reset_password), onDismiss, saveTitle = stringResource(R.string.users_reset), canSave = password.length >= 6 && password == confirmation,
        onSave = { actions.run(success = L10n.str(R.string.users_password_reset_done, user.fullName), onDone = onDismiss) { catalog.resetPassword(user, password) } },
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
            null, footer = problem ?: stringResource(R.string.users_reset_footer),
            footerColor = if (problem != null) Tokens.colors.danger else null,
        ) {
            SecureField(password, { password = it }, stringResource(R.string.users_new_password))
            SecureField(confirmation, { confirmation = it }, stringResource(R.string.users_confirm_password))
        }
    }
}
