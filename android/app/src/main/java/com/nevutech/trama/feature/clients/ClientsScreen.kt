package com.nevutech.trama.feature.clients

import androidx.compose.foundation.layout.Spacer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material3.HorizontalDivider
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
import com.nevutech.trama.core.data.ClientEntity
import com.nevutech.trama.core.data.ContactLinks
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun ClientsScreen() {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    val context = LocalContext.current
    var search by rememberSaveable { mutableStateOf("") }
    var editor by remember { mutableStateOf<PartyEditorTarget<ClientEntity>?>(null) }
    var pendingDelete by remember { mutableStateOf<ClientEntity?>(null) }

    val clients = graph.clients
    val filtered = clients.filter { c ->
        catalogMatches(search, listOf(c.name, c.address) + graph.contactsOfClient(c.id).flatMap { listOf(it.name, it.email, it.role) })
    }

    TramaScreen {
        CatalogGrid(stringResource(R.string.section_clients), search, { search = it }, stringResource(R.string.clients_search), stringResource(R.string.clients_new), { editor = PartyEditorTarget(null) }) {
            when {
                clients.isEmpty() -> fullSpan {
                    EmptyState(stringResource(R.string.clients_empty_title), stringResource(R.string.clients_empty_message), Icons.Filled.Groups) {
                        PrimaryButton(stringResource(R.string.clients_new), { editor = PartyEditorTarget(null) }, icon = Icons.Filled.Add)
                    }
                }
                filtered.isEmpty() -> fullSpan { NoResults(search) }
                else -> items(filtered.size, key = { filtered[it].id }) { i ->
                    val client = filtered[i]
                    val contacts = graph.contactsOfClient(client.id)
                    val orders = graph.ordersOf(client)
                    val projects = graph.projects.count { it.clientId == client.id }
                    WithContextMenu(menu = { close ->
                        MenuItem(stringResource(R.string.common_edit), Icons.Filled.Edit) { close(); editor = PartyEditorTarget(client) }
                        ContactLinks.mailto(contacts.map { it.email })?.let { uri ->
                            MenuItem(stringResource(R.string.catalog_ui_email_all), Icons.Filled.Email) { close(); openLink(context, app.toasts, uri) }
                        }
                        HorizontalDivider()
                        MenuItem(stringResource(R.string.common_delete), Icons.Filled.Delete, destructive = true) { close(); pendingDelete = client }
                    }) { open ->
                        PartyCard(client.name, client.address, contacts, onClick = { navigator.openClient(client.id) }, onLongClick = open) {
                            CardStat(Icons.Filled.ContentCut, Fmt.int(orders.size), stringResource(R.string.clients_stat_cuts))
                            Spacer(Modifier.weight(1f))
                            CardStat(Icons.Filled.Folder, Fmt.int(projects), stringResource(R.string.clients_stat_projects), Tokens.colors.info)
                            Spacer(Modifier.weight(1f))
                            CardStat(Icons.Filled.Payments, Fmt.money(orders.sumOf { it.quantity * it.unitPrice }, compact = true), stringResource(R.string.catalog_ui_value_lower), Tokens.colors.success)
                        }
                    }
                }
            }
        }
    }

    editor?.let { target ->
        PartyEditorSheet(
            PartyKind.Client, client = target.item,
            existingContacts = target.item?.let { graph.contactsOfClient(it.id) }.orEmpty(),
            startWithNewContact = target.addingContact, onDismiss = { editor = null },
        )
    }
    pendingDelete?.let { client ->
        ConfirmDeleteDialog(
            stringResource(R.string.catalog_ui_delete_title, client.name), stringResource(R.string.clients_delete_message_list),
            onConfirm = { actions.run(success = L10n.str(R.string.clients_deleted, client.name)) { app.production().deleteClient(client) } },
            onDismiss = { pendingDelete = null },
        )
    }
}
