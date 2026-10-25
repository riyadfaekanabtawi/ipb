package com.nevutech.trama.feature.orders

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.toLocalDate
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.DecimalField
import com.nevutech.trama.designsystem.IntField
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.feature.production.TramaDatePickerDialog
import com.nevutech.trama.feature.production.isWideLayout
import java.time.LocalDate

/** Create/edit a cut order (port of iOS OrderEditorSheet). [order] null creates a new one. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrderEditorSheet(order: CutOrderEntity?, onDismiss: () -> Unit) {
    val graph by rememberGraph()
    val app = LocalApp.current
    val actions = rememberActions()
    val assigned = order?.let { graph.assignedQuantity(it) } ?: 0L

    var code by remember { mutableStateOf(order?.code.orEmpty()) }
    var list by remember { mutableStateOf(order?.list.orEmpty()) }
    var garment by remember { mutableStateOf(order?.garment.orEmpty()) }
    var quantity by remember { mutableIntStateOf(order?.quantity?.toInt() ?: 0) }
    var unitPrice by remember { mutableDoubleStateOf(order?.unitPrice ?: 0.0) }
    var clientId by remember { mutableStateOf(order?.clientId) }
    var styleId by remember { mutableStateOf(order?.styleId) }
    var hasInternalDate by remember { mutableStateOf(order?.let { it.internalDate != null } ?: true) }
    var internalDate by remember { mutableStateOf(order?.internalDate?.toLocalDate() ?: LocalDate.now()) }
    var hasClientDate by remember { mutableStateOf(order?.let { it.clientDate != null } ?: true) }
    var clientDate by remember { mutableStateOf(order?.clientDate?.toLocalDate() ?: LocalDate.now().plusDays(30)) }
    var notes by remember { mutableStateOf(order?.notes.orEmpty()) }

    val canSave = code.isNotBlank() && quantity > 0 && unitPrice >= 0 && quantity >= assigned

    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = Tokens.colors.canvas) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).imePadding().navigationBarsPadding()
                .padding(horizontal = 24.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(if (order == null) "Nuevo corte" else "Editar corte", style = MaterialTheme.typography.headlineSmall)

            SectionLabel("Identificación")
            CapsField(code, { code = it }, "Código de corte")
            Pair2({ CapsField(list, { list = it }, "Lista", it) }, { TramaField(garment, { garment = it }, "Prenda (ej. Falda, Jeans)", it) })

            SectionLabel("Cliente y estilo")
            Pair2(
                { PickerField("Cliente", graph.client(clientId)?.name ?: "Sin cliente", listOf<Pair<String, String?>>("Sin cliente" to null) + graph.clients.sortedBy { c -> c.name.lowercase() }.map { c -> c.name to c.id }, { clientId = it }, it) },
                { PickerField("Estilo", graph.style(styleId)?.name ?: "Sin estilo", listOf<Pair<String, String?>>("Sin estilo" to null) + graph.styles.sortedBy { s -> s.name.lowercase() }.map { s -> s.name to s.id }, { styleId = it }, it) },
            )

            SectionLabel("Cantidad y precio")
            Pair2({ IntField(quantity, { quantity = it }, "Cantidad", it) }, { DecimalField(unitPrice, { unitPrice = it }, "Precio unitario", it) })
            Text("Ingreso total: ${Fmt.money(quantity * unitPrice)}", color = Tokens.colors.secondary, style = MaterialTheme.typography.bodyMedium)
            if (order != null && quantity < assigned) {
                Text(
                    "Ya hay ${Fmt.int(assigned)} prendas asignadas; la cantidad no puede ser menor.",
                    color = Tokens.colors.danger, style = MaterialTheme.typography.bodySmall,
                )
            }

            SectionLabel("Fechas")
            DateToggleField("Fecha interna", "Fecha interna", hasInternalDate, { hasInternalDate = it }, internalDate) { internalDate = it }
            DateToggleField("Fecha cliente", "Fecha de entrega al cliente", hasClientDate, { hasClientDate = it }, clientDate) { clientDate = it }

            SectionLabel("Notas")
            TramaField(notes, { notes = it }, "Notas", singleLine = false)

            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onDismiss) { Text("Cancelar") }
                Spacer(Modifier.weight(1f))
                PrimaryButton(
                    "Guardar", enabled = canSave, modifier = Modifier.widthIn(min = 180.dp),
                    onClick = {
                        val trimmed = code.trim()
                        actions.run(success = if (order == null) "Corte $trimmed creado" else "Corte $trimmed actualizado", onDone = onDismiss) {
                            app.production().saveOrder(
                                order, code, list, garment, quantity.toLong(), unitPrice, clientId, styleId,
                                if (hasInternalDate) internalDate else null, if (hasClientDate) clientDate else null, notes.ifBlank { null },
                            )
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) =
    Text(text, style = MaterialTheme.typography.labelLarge, color = Tokens.colors.secondary, modifier = Modifier.padding(top = 4.dp))

@Composable
private fun Pair2(first: @Composable (Modifier) -> Unit, second: @Composable (Modifier) -> Unit) {
    if (isWideLayout()) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { first(Modifier.weight(1f)); second(Modifier.weight(1f)) }
    } else {
        first(Modifier); second(Modifier)
    }
}

@Composable
private fun CapsField(value: String, onChange: (String) -> Unit, label: String, modifier: Modifier = Modifier) {
    OutlinedTextField(
        value, onChange, modifier.fillMaxWidth(), label = { Text(label) }, singleLine = true,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters), shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface),
    )
}

/** Read-only field that opens a menu of options; each option carries the selected id. */
@Composable
fun <T> PickerField(label: String, value: String, options: List<Pair<String, T>>, onSelect: (T) -> Unit, modifier: Modifier = Modifier) {
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        OutlinedTextField(
            value, {}, Modifier.fillMaxWidth(), readOnly = true, label = { Text(label) }, singleLine = true,
            trailingIcon = { Icon(Icons.Filled.KeyboardArrowDown, null) }, shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface),
        )
        // Transparent overlay: a read-only text field swallows taps otherwise.
        Box(Modifier.matchParentSize().clickable(role = Role.DropdownList, onClickLabel = label) { open = true })
        DropdownMenu(open, { open = false }) {
            options.forEach { (title, id) -> DropdownMenuItem(text = { Text(title) }, onClick = { open = false; onSelect(id) }) }
        }
    }
}

/** Switch + date field; the date opens a Material date picker. */
@Composable
fun DateToggleField(toggleLabel: String, dateLabel: String, enabled: Boolean, onEnabled: (Boolean) -> Unit, date: LocalDate, onDate: (LocalDate) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(toggleLabel, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Switch(enabled, onEnabled)
    }
    if (enabled) DateField(dateLabel, date, onDate)
}

/** Read-only date field that opens a Material date picker. */
@Composable
fun DateField(dateLabel: String, date: LocalDate, onDate: (LocalDate) -> Unit) {
    var picking by remember { mutableStateOf(false) }
    Box {
        OutlinedTextField(
            Fmt.date(date), {}, Modifier.fillMaxWidth(), readOnly = true, label = { Text(dateLabel) }, singleLine = true,
            leadingIcon = { Icon(Icons.Filled.CalendarMonth, null, tint = Tokens.colors.brand) }, shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface),
        )
        Box(Modifier.matchParentSize().clickable(role = Role.Button, onClickLabel = dateLabel) { picking = true })
    }
    if (picking) TramaDatePickerDialog(date, onDate) { picking = false }
}
