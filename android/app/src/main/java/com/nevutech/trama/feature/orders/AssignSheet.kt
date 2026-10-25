package com.nevutech.trama.feature.orders

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.domain.AssignmentRules
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.Avatar
import com.nevutech.trama.designsystem.CapacityBar
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.InfoRow
import com.nevutech.trama.designsystem.Pill
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.SectionHeader
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.feature.production.bestFitPlant
import com.nevutech.trama.feature.production.fromPickerMillis
import com.nevutech.trama.feature.production.isWideLayout
import com.nevutech.trama.feature.production.toPickerMillis
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

private val monthFormat = DateTimeFormatter.ofPattern("MMMM", Fmt.locale)

/**
 * Assign part of a cut order to a plant for a month. Every plant shows its capacity for the chosen
 * month with a live preview of what this assignment would add, so the planner sees the fit first.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun AssignSheet(orderId: String, onDismiss: () -> Unit) {
    val graph by rememberGraph()
    val app = LocalApp.current
    val actions = rememberActions()
    val order = graph.order(orderId) ?: return
    val remaining = graph.remaining(order).toInt()
    val plants = graph.plants.sortedBy { it.name.lowercase() }

    var quantity by remember { mutableIntStateOf(remaining) }
    val dateState = rememberDatePickerState(initialSelectedDateMillis = LocalDate.now().toPickerMillis())
    val date: LocalDate? = dateState.selectedDateMillis?.fromPickerMillis()
    val value = quantity * order.unitPrice
    var selectedId by remember { mutableStateOf(bestFitPlant(graph, plants, LocalDate.now(), value)?.id) }
    val selected = plants.firstOrNull { it.id == selectedId }
    val validation = selected?.let { AssignmentRules.validate(quantity, order.unitPrice, remaining, date, graph.ledger(it)) }
    val wide = isWideLayout(840)

    Dialog(onDismiss, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        TramaScreen(Modifier.statusBarsPadding().navigationBarsPadding().imePadding()) {
            Column(Modifier.fillMaxSize()) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onDismiss) { Icon(Icons.Filled.Close, "Cancelar") }
                    Text("Asignar ${order.code}", style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
                }
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(if (wide) 24.dp else 16.dp)) {
                    val controls: @Composable (Modifier) -> Unit = { m ->
                        Column(m, verticalArrangement = Arrangement.spacedBy(20.dp)) {
                            TramaCard {
                                SectionHeader("Cantidad", "${Fmt.int(remaining)} prendas pendientes de ${Fmt.int(order.quantity)}")
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    var text by remember(quantity) { mutableStateOf(if (quantity == 0) "" else quantity.toString()) }
                                    TextField(
                                        text,
                                        { raw -> val digits = raw.filter(Char::isDigit).take(9); text = digits; quantity = digits.toIntOrNull() ?: 0 },
                                        Modifier.weight(1f), singleLine = true, placeholder = { Text("0", fontSize = 40.sp) },
                                        textStyle = TextStyle(fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Tokens.colors.ink),
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                        colors = TextFieldDefaults.colors(
                                            focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent,
                                            unfocusedIndicatorColor = Tokens.colors.stroke,
                                        ),
                                    )
                                    Text("prendas", color = Tokens.colors.secondary, modifier = Modifier.padding(start = 8.dp))
                                }
                                Slider(
                                    quantity.coerceIn(0, maxOf(remaining, 1)).toFloat(), { quantity = it.roundToInt() },
                                    valueRange = 0f..maxOf(remaining, 1).toFloat(),
                                )
                                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    listOf(0.25, 0.5, 1.0).forEach { f ->
                                        OutlinedButton({ quantity = (remaining * f).roundToInt() }) { Text(if (f == 1.0) "Todo" else Fmt.percent(f)) }
                                    }
                                }
                                InfoRow("Valor de la asignación", Fmt.money(value), Icons.Filled.Payments)
                            }
                            TramaCard(padding = 12.dp) {
                                SectionHeader("Mes de producción", "La capacidad de cada planta es mensual")
                                DatePicker(dateState, showModeToggle = false, title = null, headline = null, colors = DatePickerDefaults.colors(containerColor = Color.Transparent))
                            }
                            val distribution = graph.style(order.styleId)?.let(graph::plantDistribution).orEmpty()
                            if (distribution.isNotEmpty()) {
                                TramaCard {
                                    SectionHeader("Este estilo ya se produce en")
                                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        distribution.forEach { (plant, count) -> Pill("${plant.name} · $count", Tokens.accent(plant.name), Icons.Filled.Apartment) }
                                    }
                                }
                            }
                        }
                    }
                    val picker: @Composable (Modifier) -> Unit = { m ->
                        Column(m, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            val monthTitle = date?.let { Fmt.monthYear(it) } ?: "—"
                            SectionHeader("Plantas", "Capacidad de $monthTitle")
                            if (plants.isEmpty()) EmptyState("No hay plantas", "Crea una planta en Catálogos → Plantas.", Icons.Filled.Apartment)
                            plants.forEach { plant ->
                                PlantCapacityOption(graph, plant, date ?: LocalDate.now(), value, plant.id == selectedId) { selectedId = plant.id }
                            }
                        }
                    }
                    if (wide) {
                        Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) { controls(Modifier.width(380.dp)); picker(Modifier.weight(1f)) }
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(20.dp)) { controls(Modifier.fillMaxWidth()); picker(Modifier.fillMaxWidth()) }
                    }
                }
                // Summary bar with live validation.
                Surface(color = Tokens.colors.surfaceRaised, border = BorderStroke(1.dp, Tokens.colors.stroke)) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Column(Modifier.weight(1f)) {
                            if (selected != null) {
                                Text("${Fmt.int(quantity)} prendas → ${selected.name}", style = MaterialTheme.typography.titleMedium)
                                val error = validation?.exceptionOrNull()
                                if (error != null) Text(error.message.orEmpty(), style = MaterialTheme.typography.bodySmall, color = Tokens.colors.danger)
                                else Text("${Fmt.money(value)} en ${date?.format(monthFormat).orEmpty()}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                            } else {
                                Text("Elige una planta", style = MaterialTheme.typography.titleMedium)
                            }
                        }
                        PrimaryButton(
                            "Asignar", icon = Icons.Filled.Check, enabled = validation?.isSuccess == true, modifier = Modifier.widthIn(min = if (wide) 200.dp else 130.dp),
                            onClick = {
                                val plant = selected ?: return@PrimaryButton
                                actions.run(success = "Asignaste ${Fmt.int(quantity)} prendas a ${plant.name}", onDone = onDismiss) {
                                    app.production().assign(order.id, plant.id, quantity, date)
                                }
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PlantCapacityOption(graph: Graph, plant: PlantEntity, date: LocalDate, preview: Double, selected: Boolean, onSelect: () -> Unit) {
    val c = Tokens.colors
    val month = YearMonth.from(date)
    val ledger = graph.ledger(plant)
    val used = ledger.used(month)
    val available = ledger.available(month)
    val fits = preview <= available + 0.0001
    Surface(
        Modifier.fillMaxWidth().selectable(selected, role = Role.RadioButton, onClick = onSelect),
        shape = RoundedCornerShape(18.dp), color = c.surface,
        border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) c.brand else c.stroke),
    ) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar(plant.name, size = 40.dp, icon = Icons.Filled.Apartment)
                Column(Modifier.weight(1f)) {
                    Text(plant.name, style = MaterialTheme.typography.titleMedium)
                    Text("Máx. ${Fmt.money(plant.maxCapacity)}/mes", style = MaterialTheme.typography.bodySmall, color = c.secondary)
                }
                Pill(if (fits) "Cabe" else "Excede", if (fits) c.success else c.danger, if (fits) Icons.Filled.Check else Icons.Filled.Warning)
                Icon(
                    if (selected) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null,
                    tint = if (selected) c.brand else c.secondary.copy(alpha = 0.4f), modifier = Modifier.size(26.dp),
                )
            }
            CapacityBar(used, plant.maxCapacity, preview = if (selected) preview else 0.0, height = 14.dp)
            Row {
                Text("Usado ${Fmt.money(used, compact = true)}", style = MaterialTheme.typography.labelMedium, color = c.secondary, modifier = Modifier.weight(1f))
                Text(
                    "Disponible ${Fmt.money(maxOf(0.0, available), compact = true)}", style = MaterialTheme.typography.labelMedium,
                    color = if (available > 0) c.success else c.danger,
                )
            }
        }
    }
}
