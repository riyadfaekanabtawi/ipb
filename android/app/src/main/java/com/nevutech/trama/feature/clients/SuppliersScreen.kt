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
import androidx.compose.ui.res.stringResource
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.ContactLinks
import com.nevutech.trama.core.data.SupplierEntity
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.l10n.L10n
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
        CatalogGrid(stringResource(R.string.section_suppliers), search, { search = it }, stringResource(R.string.suppliers_search), stringResource(R.string.suppliers_new), { editor = PartyEditorTarget(null) }) {
            when {
                suppliers.isEmpty() -> fullSpan {
                    EmptyState(stringResource(R.string.suppliers_empty_title), stringResource(R.string.suppliers_empty_message), Icons.Filled.LocalShipping) {
                        PrimaryButton(stringResource(R.string.suppliers_new), { editor = PartyEditorTarget(null) }, icon = Icons.Filled.Add)
                    }
                }
                filtered.isEmpty() -> fullSpan { NoResults(search) }
                else -> items(filtered.size, key = { filtered[it].id }) { i ->
                    val supplier = filtered[i]
                    val contacts = graph.contactsOfSupplier(supplier.id)
                    WithContextMenu(menu = { close ->
                        MenuItem(stringResource(R.string.common_edit), Icons.Filled.Edit) { close(); editor = PartyEditorTarget(supplier) }
                        ContactLinks.mailto(contacts.map { it.email })?.let { uri ->
                            MenuItem(stringResource(R.string.catalog_ui_email_all), Icons.Filled.Email) { close(); openLink(context, app.toasts, uri) }
                        }
                        HorizontalDivider()
                        MenuItem(stringResource(R.string.common_delete), Icons.Filled.Delete, destructive = true) { close(); pendingDelete = supplier }
                    }) { open ->
                        PartyCard(supplier.name, supplier.address, contacts, Icons.Filled.LocalShipping, onClick = { navigator.openSupplier(supplier.id) }, onLongClick = open) {
                            CardStat(Icons.Filled.Groups, Fmt.int(contacts.size), stringResource(R.string.suppliers_stat_contacts))
                            Spacer(Modifier.weight(1f))
                            val first = contacts.firstOrNull()
                            ContactLinks.mailto(listOf(first?.email))?.let { uri ->
                                FilledTonalIconButton({ openLink(context, app.toasts, uri) }) { Icon(Icons.Filled.Email, stringResource(R.string.catalog_ui_email_to, first?.email.orEmpty())) }
                            }
                            ContactLinks.tel(first?.phone)?.let { uri ->
                                FilledTonalIconButton({ openLink(context, app.toasts, uri) }) { Icon(Icons.Filled.Phone, stringResource(R.string.catalog_ui_call, first?.phone.orEmpty())) }
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
            stringResource(R.string.catalog_ui_delete_title, supplier.name),
            onConfirm = { actions.run(success = L10n.str(R.string.suppliers_deleted, supplier.name)) { catalog.deleteSupplier(supplier) } },
            onDismiss = { pendingDelete = null },
        )
    }
}
