package com.nevutech.trama.feature.clients

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CallMade
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.MarkEmailUnread
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material.icons.outlined.HelpOutline
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.core.data.ContactDraft
import com.nevutech.trama.core.data.ContactEntity
import com.nevutech.trama.core.data.ContactLinks
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.unit.Dp

/**
 * Form section that edits any number of contacts (legacy had three fixed slots). Rows can be
 * added, removed and moved up/down; the first one is the main contact.
 */
@Composable
fun ContactsEditorSection(contacts: List<ContactDraft>, onChange: (List<ContactDraft>) -> Unit, focusId: String? = null) {
    FormSection(
        "Contactos",
        footer = if (contacts.size > 1) "Usa el menú de cada contacto para reordenarlo. El primero es el contacto principal." else null,
    ) {
        contacts.forEachIndexed { index, contact ->
            if (index > 0) HorizontalDivider(color = Tokens.colors.stroke)
            ContactEditorRow(
                contact, index + 1,
                canMoveUp = index > 0, canMoveDown = index < contacts.lastIndex,
                onChange = { updated -> onChange(contacts.map { if (it.id == contact.id) updated else it }) },
                move = { offset ->
                    val target = index + offset
                    if (target in contacts.indices) onChange(contacts.toMutableList().apply { add(target, removeAt(index)) })
                },
                remove = { onChange(contacts.filterNot { it.id == contact.id }) },
                autoFocus = contact.id == focusId,
            )
        }
        TextButton({ onChange(contacts + ContactDraft()) }) {
            Icon(Icons.Filled.PersonAdd, null, Modifier.size(18.dp))
            Text("  Agregar contacto")
        }
    }
}

@Composable
private fun ContactEditorRow(
    contact: ContactDraft,
    position: Int,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onChange: (ContactDraft) -> Unit,
    move: (Int) -> Unit,
    remove: () -> Unit,
    autoFocus: Boolean,
) {
    val focus = remember { FocusRequester() }
    LaunchedEffect(autoFocus) { if (autoFocus) runCatching { focus.requestFocus() } }
    Column(Modifier.animateContentSize(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Avatar(contact.name.ifBlank { "$position" }, size = 34.dp)
            TramaField(contact.name, { onChange(contact.copy(name = it)) }, "Nombre", Modifier.weight(1f).focusRequester(focus))
            var open by remember { mutableStateOf(false) }
            Box {
                IconButton({ open = true }) { Icon(Icons.Filled.MoreHoriz, "Opciones del contacto $position", tint = Tokens.colors.secondary) }
                DropdownMenu(open, { open = false }) {
                    MenuItem("Subir", Icons.Filled.ArrowUpward, enabled = canMoveUp) { open = false; move(-1) }
                    MenuItem("Bajar", Icons.Filled.ArrowDownward, enabled = canMoveDown) { open = false; move(1) }
                    HorizontalDivider()
                    MenuItem("Quitar contacto", Icons.Filled.Delete, destructive = true) { open = false; remove() }
                }
            }
        }
        TramaField(contact.role, { onChange(contact.copy(role = it)) }, "Puesto", leading = Icons.Outlined.WorkOutline)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            TramaField(contact.email, { onChange(contact.copy(email = it)) }, "Correo", Modifier.weight(1f), keyboard = KeyboardType.Email, leading = Icons.Outlined.Email)
            TramaField(contact.phone, { onChange(contact.copy(phone = it)) }, "Teléfono", Modifier.weight(1f), keyboard = KeyboardType.Phone, leading = Icons.Outlined.Phone)
        }
    }
}

/** Read-only contact card with tap-to-email and tap-to-call; long press copies. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ContactCard(contact: ContactEntity, isPrimary: Boolean) {
    val clipboard = LocalClipboardManager.current
    val toasts = LocalApp.current.toasts
    var menu by remember { mutableStateOf(false) }
    Box {
        TramaCard(
            Modifier.fillMaxWidth().clip(Tokens.cardShape).combinedClickable(onClick = {}, onLongClick = { menu = true }, onLongClickLabel = "Copiar datos"),
            padding = 18.dp,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar(contact.name ?: "?", size = 46.dp)
                Column(Modifier.weight(1f)) {
                    Text(contact.name ?: "Sin nombre", style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(contact.role ?: "Sin puesto", style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, maxLines = 1)
                }
                if (isPrimary) Pill("Principal", Tokens.colors.thread, Icons.Filled.Star)
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                val email = contact.email
                val phone = contact.phone
                ContactLinks.mailto(listOf(email))?.let { ContactLinkRow(Icons.Filled.Email, email!!, it, "Enviar correo a $email") }
                ContactLinks.tel(phone)?.let { ContactLinkRow(Icons.Filled.Phone, phone!!, it, "Llamar a $phone") }
                if (email == null && phone == null) {
                    Text("Sin datos de contacto", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary.copy(alpha = 0.6f))
                }
            }
        }
        DropdownMenu(menu, { menu = false }) {
            contact.email?.let { e -> MenuItem("Copiar correo", Icons.Filled.ContentCopy) { menu = false; clipboard.setText(AnnotatedString(e)); toasts.show("Correo copiado") } }
            contact.phone?.let { p -> MenuItem("Copiar teléfono", Icons.Filled.ContentCopy) { menu = false; clipboard.setText(AnnotatedString(p)); toasts.show("Teléfono copiado") } }
        }
    }
}

@Composable
private fun ContactLinkRow(icon: ImageVector, text: String, uri: String, label: String) {
    val context = LocalContext.current
    val toasts = LocalApp.current.toasts
    Row(
        Modifier.fillMaxWidth().clip(Tokens.chipShape).clickable { openLink(context, toasts, uri) }
            .semantics(mergeDescendants = true) { contentDescription = label }.padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(30.dp).clip(CircleShape).background(Tokens.colors.brand.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Tokens.colors.brand, modifier = Modifier.size(16.dp))
        }
        Text(text, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.MiddleEllipsis, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.CallMade, null, tint = Tokens.colors.secondary.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
    }
}

/** Contacts block for detail screens: header with "Enviar correo a todos" plus a grid of cards. */
@Composable
fun ContactsSection(contacts: List<ContactEntity>, onAdd: (() -> Unit)?) {
    val context = LocalContext.current
    val toasts = LocalApp.current.toasts
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        val subtitle = when (contacts.size) { 0 -> "Sin contactos"; 1 -> "1 contacto"; else -> "${contacts.size} contactos" }
        SectionTitle("Contactos", subtitle) {
            val all = ContactLinks.mailto(contacts.map { it.email })
            if (all != null && contacts.size > 1) {
                OutlinedButton({ openLink(context, toasts, all) }) {
                    Icon(Icons.Filled.MarkEmailUnread, null, Modifier.size(18.dp))
                    Text("  Enviar correo a todos")
                }
            }
        }
        if (contacts.isEmpty()) {
            TramaCard(Modifier.fillMaxWidth()) {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Aún no hay contactos.", color = Tokens.colors.secondary)
                    if (onAdd != null) OutlinedButton(onAdd) {
                        Icon(Icons.Filled.PersonAdd, null, Modifier.size(18.dp))
                        Text("  Agregar contacto")
                    }
                }
            }
        } else {
            AdaptiveRows(contacts, minWidth = 280.dp) { contact ->
                ContactCard(contact, isPrimary = contact.id == contacts.first().id && contacts.size > 1)
            }
        }
    }
}

/** Non-lazy adaptive grid for use inside scrolling detail pages. */
@Composable
fun <T> AdaptiveRows(items: List<T>, minWidth: Dp, spacing: Dp = 14.dp, content: @Composable (T) -> Unit) {
    androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxWidth()) {
        val columns = maxOf(1, ((maxWidth + spacing) / (minWidth + spacing)).toInt())
        Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
            items.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                    row.forEach { item -> Box(Modifier.weight(1f)) { content(item) } }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

/** Compact contact line used on list cards. */
@Composable
fun PrimaryContactLine(contacts: List<ContactEntity>) {
    val first = contacts.firstOrNull()
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (first != null) {
            Icon(Icons.Outlined.AccountCircle, null, tint = Tokens.colors.brand, modifier = Modifier.size(18.dp))
            Text(first.name ?: first.email ?: "Contacto", style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (contacts.size > 1) Text("+${contacts.size - 1}", style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary)
        } else {
            Icon(Icons.Outlined.HelpOutline, null, tint = Tokens.colors.secondary.copy(alpha = 0.6f), modifier = Modifier.size(18.dp))
            Text("Sin contactos", style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary.copy(alpha = 0.6f))
        }
    }
}
