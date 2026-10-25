package com.nevutech.trama.feature.clients

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CallMade
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.ClientEntity
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.ProjectEntity
import com.nevutech.trama.core.data.statusValue
import com.nevutech.trama.core.data.total
import com.nevutech.trama.core.domain.AppSection
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.tint

@Composable
fun ClientDetailScreen(id: String) {
    val app = LocalApp.current
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val actions = rememberActions()
    val context = LocalContext.current
    var editor by remember { mutableStateOf<PartyEditorTarget<ClientEntity>?>(null) }
    var confirmingDelete by remember { mutableStateOf(false) }

    val client = graph.client(id)
    TramaScreen {
        if (client == null) {
            DetailScaffold("Cliente") { EmptyState("Cliente no encontrado", "Es posible que se haya eliminado.", Icons.Filled.PersonOff) }
            return@TramaScreen
        }
        val orders = graph.ordersOf(client)
        val projects = graph.projects.filter { it.clientId == client.id }.sortedByDescending { it.createdAt }
        val contacts = graph.contactsOfClient(client.id)

        DetailScaffold(client.name, actions = {
            IconButton({ editor = PartyEditorTarget(client) }) { Icon(Icons.Filled.Edit, "Editar") }
            OverflowMenu { close ->
                mapsLink(client.address)?.let { uri -> MenuItem("Abrir en Mapas", Icons.Filled.Map) { close(); openLink(context, app.toasts, uri) } }
                MenuItem("Eliminar cliente", Icons.Filled.Delete, destructive = true) { close(); confirmingDelete = true }
            }
        }) {
            DetailHero(client.name, client.address ?: "Sin dirección", leading = { Avatar(client.name, size = 72.dp) }) {
                HeroStat(Fmt.int(orders.size), "Cortes")
                HeroStat(Fmt.int(orders.sumOf { it.quantity }), "Prendas")
                HeroStat(Fmt.money(orders.sumOf { it.quantity * it.unitPrice }, compact = true), "Valor")
            }

            ContactsSection(contacts) { editor = PartyEditorTarget(client, addingContact = true) }

            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SectionTitle("Cortes", if (orders.isEmpty()) "Sin cortes" else "${Fmt.int(orders.size)} cortes")
                if (orders.isEmpty()) {
                    TramaCard(Modifier.fillMaxWidth()) {
                        Text("Este cliente aún no tiene cortes.", color = Tokens.colors.secondary, modifier = Modifier.align(Alignment.CenterHorizontally))
                    }
                } else {
                    orders.forEach { order -> ClientOrderRow(graph, order) { navigator.openOrder(order.id) } }
                }
            }

            if (projects.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    SectionTitle("Proyectos", "${projects.size} cotizaciones") {
                        TextButton({ navigator.openSection(AppSection.Projects) }) {
                            Text("Ver todos  ")
                            Icon(Icons.AutoMirrored.Filled.CallMade, null, Modifier.size(14.dp))
                        }
                    }
                    AdaptiveRows(projects, minWidth = 260.dp) { ClientProjectTile(app.images.file(it.photoFile), it) }
                }
            }
        }
    }

    editor?.let { target ->
        PartyEditorSheet(
            PartyKind.Client, client = target.item, existingContacts = graph.contactsOfClient(id),
            startWithNewContact = target.addingContact, onDismiss = { editor = null },
        )
    }
    if (confirmingDelete && client != null) {
        ConfirmDeleteDialog(
            "¿Eliminar ${client.name}?", "Solo se pueden eliminar clientes sin cortes.",
            onConfirm = {
                actions.run(success = "Cliente «${client.name}» eliminado", onDone = { navigator.back() }) { app.production().deleteClient(client) }
            },
            onDismiss = { confirmingDelete = false },
        )
    }
}

@Composable
private fun ClientOrderRow(graph: Graph, order: CutOrderEntity, onClick: () -> Unit) {
    val app = LocalApp.current
    val state = graph.state(order)
    val style = graph.style(order.styleId)
    CatalogRowCard(onClick) {
        Swatch(graph.styleName(order), app.images.file(style?.imageFile), Modifier.size(44.dp), corner = 10.dp)
        Column(Modifier.weight(1f)) {
            Text(order.code, style = MaterialTheme.typography.titleMedium)
            Text(
                listOfNotNull(order.list.takeIf { it.isNotBlank() }?.let { "Lista $it" }, order.garment.takeIf { it.isNotBlank() }).joinToString(" · "),
                style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary, maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(22.dp), verticalAlignment = Alignment.CenterVertically) {
            RowFigure(Fmt.int(order.quantity), "prendas")
            RowFigure(Fmt.money(order.quantity * order.unitPrice, compact = true), "valor")
            Pill(state.title, state.tint())
        }
    }
}

@Composable
private fun ClientProjectTile(photo: java.io.File?, project: ProjectEntity) {
    val status = project.statusValue
    TramaCard(Modifier.fillMaxWidth(), padding = 14.dp) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Swatch(project.fabric ?: project.clientName.orEmpty(), photo, Modifier.size(56.dp), corner = 12.dp)
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(Fmt.money(project.total), style = MaterialTheme.typography.titleMedium)
                Text("${Fmt.int(project.quantity)} prendas · ${project.fabric ?: "Sin tela"}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, maxLines = 1)
                Pill(status.title, status.displayTint(), status.icon)
            }
        }
    }
}
