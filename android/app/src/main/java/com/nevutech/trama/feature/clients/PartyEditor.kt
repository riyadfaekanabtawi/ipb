package com.nevutech.trama.feature.clients

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.core.data.ClientEntity
import com.nevutech.trama.core.data.ContactDraft
import com.nevutech.trama.core.data.ContactEntity
import com.nevutech.trama.core.data.SupplierEntity
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField

/** Which party an editor is open for; [addingContact] starts with a fresh contact row. */
data class PartyEditorTarget<T>(val item: T?, val addingContact: Boolean = false)

enum class PartyKind(val noun: String) { Client("cliente"), Supplier("proveedor") }

/** Create/edit sheet shared by clients and suppliers: name, address and any number of contacts. */
@Composable
fun PartyEditorSheet(
    kind: PartyKind,
    client: ClientEntity? = null,
    supplier: SupplierEntity? = null,
    existingContacts: List<ContactEntity>,
    startWithNewContact: Boolean,
    onDismiss: () -> Unit,
) {
    val catalog = rememberCatalog()
    val actions = rememberActions()
    val toasts = rememberToasts()
    val isNew = client == null && supplier == null
    var name by remember { mutableStateOf(client?.name ?: supplier?.name ?: "") }
    var address by remember { mutableStateOf(client?.address ?: supplier?.address ?: "") }
    val initial = remember {
        val loaded = existingContacts.map(ContactDraft::of)
        if (isNew || startWithNewContact || loaded.isEmpty()) loaded + ContactDraft() else loaded
    }
    var contacts by remember { mutableStateOf(initial) }
    val focusId = remember { if (!isNew && startWithNewContact) initial.lastOrNull()?.id else null }

    fun save() = actions.run(onDone = onDismiss) {
        when (kind) {
            PartyKind.Client -> {
                val saved = catalog.saveClient(client, name, address, contacts)
                toasts.show(if (isNew) "Cliente «${saved.name}» creado" else "Cliente actualizado")
            }
            PartyKind.Supplier -> {
                val saved = catalog.saveSupplier(supplier, name, address, contacts)
                toasts.show(if (isNew) "Proveedor «${saved.name}» creado" else "Proveedor actualizado")
            }
        }
    }

    FormSheet(
        title = if (isNew) "Nuevo ${kind.noun}" else "Editar ${kind.noun}",
        onDismiss = onDismiss, onSave = ::save, canSave = name.isNotBlank(),
    ) {
        FormSection("Datos generales") {
            TramaField(name, { name = it }, "Nombre")
            TramaField(address, { address = it }, "Dirección", singleLine = false, leading = Icons.Outlined.LocationOn)
        }
        ContactsEditorSection(contacts, { contacts = it }, focusId)
    }
}

/** Card used by both the clients and the suppliers grids. */
@Composable
fun PartyCard(
    name: String,
    address: String?,
    contacts: List<ContactEntity>,
    icon: ImageVector? = null,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    footer: @Composable RowScope.() -> Unit,
) {
    TramaCard(Modifier.fillMaxWidth().cardClick(onClick, onLongClick)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Avatar(name, size = 52.dp, icon = icon)
            Column(Modifier.weight(1f)) {
                Text(name, style = MaterialTheme.typography.titleLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Outlined.LocationOn, null, tint = Tokens.colors.secondary, modifier = Modifier.size(15.dp))
                    Text(address ?: "Sin dirección", style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
        PrimaryContactLine(contacts)
        HorizontalDivider(color = Tokens.colors.stroke)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, content = footer)
    }
}
