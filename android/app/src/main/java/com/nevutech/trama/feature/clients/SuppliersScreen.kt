package com.nevutech.trama.feature.clients

import androidx.compose.foundation.layout.Spacer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.ContactLinks
import com.nevutech.trama.core.data.SupplierEntity
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun SuppliersScreen() {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    val catalog = rememberCatalog()
    val context = LocalContext.current
    var search by rememberSaveable { mutableStateOf("") }
    var editor by remember { mutableStateOf<PartyEditorTarget<SupplierEntity>?>(null) }
    var pendingDelete by remember { mutableStateOf<SupplierEntity?>(null) }

    val suppliers = graph.suppliers
    val filtered = suppliers.filter { s ->
        catalogMatches(search, listOf(s.name, s.address) + graph.contactsOfSupplier(s.id).flatMap { listOf(it.name, it.email, it.role) })
    }

    TramaScreen {
        CatalogGrid("Proveedores", search, { search = it }, "Buscar proveedor, contacto o correo", "Nuevo proveedor", { editor = PartyEditorTarget(null) }) {
            when {
                suppliers.isEmpty() -> fullSpan {
                    EmptyState("Sin proveedores", "Guarda a tus proveedores de telas, hilos y avíos con sus contactos.", Icons.Filled.LocalShipping) {
                        PrimaryButton("Nuevo proveedor", { editor = PartyEditorTarget(null) }, icon = Icons.Filled.Add)
                    }
                }
                filtered.isEmpty() -> fullSpan { NoResults(search) }
                else -> items(filtered.size, key = { filtered[it].id }) { i ->
                    val supplier = filtered[i]
                    val contacts = graph.contactsOfSupplier(supplier.id)
                    WithContextMenu(menu = { close ->
                        MenuItem("Editar", Icons.Filled.Edit) { close(); editor = PartyEditorTarget(supplier) }
                        ContactLinks.mailto(contacts.map { it.email })?.let { uri ->
                            MenuItem("Enviar correo a todos", Icons.Filled.Email) { close(); openLink(context, app.toasts, uri) }
                        }
                        HorizontalDivider()
                        MenuItem("Eliminar", Icons.Filled.Delete, destructive = true) { close(); pendingDelete = supplier }
                    }) { open ->
                        PartyCard(supplier.name, supplier.address, contacts, Icons.Filled.LocalShipping, onClick = { navigator.openSupplier(supplier.id) }, onLongClick = open) {
                            CardStat(Icons.Filled.Groups, Fmt.int(contacts.size), "contactos")
                            Spacer(Modifier.weight(1f))
                            val first = contacts.firstOrNull()
                            ContactLinks.mailto(listOf(first?.email))?.let { uri ->
                                FilledTonalIconButton({ openLink(context, app.toasts, uri) }) { Icon(Icons.Filled.Email, "Enviar correo a ${first?.email}") }
                            }
                            ContactLinks.tel(first?.phone)?.let { uri ->
                                FilledTonalIconButton({ openLink(context, app.toasts, uri) }) { Icon(Icons.Filled.Phone, "Llamar a ${first?.phone}") }
                            }
                        }
                    }
                }
            }
        }
    }

    editor?.let { target ->
        PartyEditorSheet(
            PartyKind.Supplier, supplier = target.item,
            existingContacts = target.item?.let { graph.contactsOfSupplier(it.id) }.orEmpty(),
            startWithNewContact = target.addingContact, onDismiss = { editor = null },
        )
    }
    pendingDelete?.let { supplier ->
        ConfirmDeleteDialog(
            "¿Eliminar ${supplier.name}?",
            onConfirm = { actions.run(success = "Proveedor «${supplier.name}» eliminado") { catalog.deleteSupplier(supplier) } },
            onDismiss = { pendingDelete = null },
        )
    }
}
