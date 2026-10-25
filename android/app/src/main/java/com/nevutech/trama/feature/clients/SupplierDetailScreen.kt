package com.nevutech.trama.feature.clients

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.SupplierEntity
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun SupplierDetailScreen(id: String) {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    val catalog = rememberCatalog()
    val context = LocalContext.current
    var editor by remember { mutableStateOf<PartyEditorTarget<SupplierEntity>?>(null) }
    var confirmingDelete by remember { mutableStateOf(false) }

    val supplier = graph.supplier(id)
    TramaScreen {
        if (supplier == null) {
            DetailScaffold("Proveedor") { EmptyState("Proveedor no encontrado", "Es posible que se haya eliminado.", Icons.Filled.SearchOff) }
            return@TramaScreen
        }
        val contacts = graph.contactsOfSupplier(supplier.id)
        DetailScaffold(supplier.name, actions = {
            IconButton({ editor = PartyEditorTarget(supplier) }) { Icon(Icons.Filled.Edit, "Editar") }
            OverflowMenu { close ->
                MenuItem("Eliminar proveedor", Icons.Filled.Delete, destructive = true) { close(); confirmingDelete = true }
            }
        }) {
            DetailHero(supplier.name, supplier.address ?: "Sin dirección", leading = { Avatar(supplier.name, size = 72.dp, icon = Icons.Filled.LocalShipping) }) {
                HeroStat(Fmt.int(contacts.size), if (contacts.size == 1) "Contacto" else "Contactos")
                mapsLink(supplier.address)?.let { uri ->
                    Row(
                        Modifier.clip(RoundedCornerShape(Tokens.smallRadius)).background(Color.White.copy(alpha = 0.12f))
                            .clickable { openLink(context, app.toasts, uri) }.semantics(mergeDescendants = true) { contentDescription = "Abrir dirección en Mapas" }
                            .padding(horizontal = 16.dp, vertical = 18.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(Icons.Filled.Map, null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Text("Mapas", color = Color.White, style = MaterialTheme.typography.labelLarge)
                    }
                }
            }
            ContactsSection(contacts) { editor = PartyEditorTarget(supplier, addingContact = true) }
        }
    }

    editor?.let { target ->
        PartyEditorSheet(
            PartyKind.Supplier, supplier = target.item, existingContacts = graph.contactsOfSupplier(id),
            startWithNewContact = target.addingContact, onDismiss = { editor = null },
        )
    }
    if (confirmingDelete && supplier != null) {
        ConfirmDeleteDialog(
            "¿Eliminar ${supplier.name}?",
            onConfirm = { actions.run(success = "Proveedor «${supplier.name}» eliminado", onDone = { navigator.back() }) { catalog.deleteSupplier(supplier) } },
            onDismiss = { confirmingDelete = false },
        )
    }
}
