package com.nevutech.trama.feature.calculator

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CleaningServices
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Percent
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.Numbers
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.WatchLater
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.app.rememberActions
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.domain.CalculatorConstants
import com.nevutech.trama.core.domain.CalculatorEngine
import com.nevutech.trama.core.domain.CalculatorInput
import com.nevutech.trama.core.domain.CalculatorResult
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.DecimalField
import com.nevutech.trama.designsystem.ProgressRing
import com.nevutech.trama.designsystem.ToastCenter
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaField
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.feature.dashboard.AdaptiveGrid

/**
 * Production cost calculator (port of ios CalculatorView). All formulas live in [CalculatorEngine];
 * this screen only collects inputs and renders live results as the user types.
 */
@Composable
fun CalculatorScreen() {
    val app = LocalApp.current
    val actions = rememberActions()
    val context = LocalContext.current
    val graph by rememberGraph()
    val stored by app.settings.calculatorConstants.collectAsState(initial = null)
    val constants = stored ?: CalculatorConstants()

    var client by rememberSaveable { mutableStateOf("") }
    var plantId by rememberSaveable { mutableStateOf<String?>(null) }
    var input by remember { mutableStateOf(CalculatorInput()) }
    var resetKey by remember { mutableIntStateOf(0) }
    var showConstants by remember { mutableStateOf(false) }

    val result = CalculatorEngine.compute(input, constants)
    val plantName = graph.plant(plantId)?.name
    val summary = calculatorSummary(client, plantName, input, result)
    val canShare = result.grossIncome != null || result.dailyGoal != null

    fun clear() {
        client = ""
        plantId = null
        input = CalculatorInput()
        resetKey++
        app.toasts.show("Calculadora limpia", ToastCenter.Style.Info)
    }

    TramaScreen {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val wide = maxWidth >= 940.dp
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(Modifier.widthIn(max = 1400.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    Header(
                        canShare = canShare,
                        onConstants = { showConstants = true },
                        onCopy = {
                            (context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager)
                                ?.setPrimaryClip(ClipData.newPlainText("Cálculo de producción", summary))
                            app.toasts.show("Resumen copiado")
                        },
                        onShare = { share(context, summary) },
                        onClear = ::clear,
                    )
                    AnimatedVisibility(stored != null && !constants.isComplete, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                        ConstantsBanner { showConstants = true }
                    }
                    val inputs = @Composable { m: Modifier ->
                        key(resetKey) {
                            Inputs(
                                client, { client = it }, plantId, { plantId = it }, graph.plants.map { it.id to it.name },
                                input, { input = it }, m,
                            )
                        }
                    }
                    if (wide) {
                        Row(horizontalArrangement = Arrangement.spacedBy(20.dp), verticalAlignment = Alignment.Top) {
                            inputs(Modifier.width(420.dp))
                            Results(result, constants, Modifier.weight(1f))
                        }
                    } else {
                        inputs(Modifier.fillMaxWidth())
                        Results(result, constants, Modifier.fillMaxWidth())
                    }
                }
            }
        }
    }

    if (showConstants) {
        ConstantsDialog(constants, onDismiss = { showConstants = false }) { updated ->
            showConstants = false
            actions.run(success = "Constantes guardadas") { app.settings.setCalculatorConstants(updated) }
        }
    }
}

private fun share(context: Context, text: String) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, "Cálculo de producción")
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(Intent.createChooser(send, "Compartir resumen").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

@Composable
private fun Header(canShare: Boolean, onConstants: () -> Unit, onCopy: () -> Unit, onShare: () -> Unit, onClear: () -> Unit) {
    val showTitle = LocalConfiguration.current.screenWidthDp >= 600
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        if (showTitle) Text("Calculadora", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.weight(1f))
        IconButton(onConstants) { Icon(Icons.Filled.Tune, "Constantes", tint = Tokens.colors.brand) }
        IconButton(onCopy, enabled = canShare) { Icon(Icons.Filled.ContentCopy, "Copiar resumen", tint = if (canShare) Tokens.colors.brand else Tokens.colors.secondary.copy(alpha = 0.4f)) }
        IconButton(onShare, enabled = canShare) { Icon(Icons.Filled.Share, "Compartir resumen", tint = if (canShare) Tokens.colors.brand else Tokens.colors.secondary.copy(alpha = 0.4f)) }
        TextButton(onClear) {
            Icon(Icons.Filled.CleaningServices, null, tint = Tokens.colors.danger, modifier = Modifier.size(18.dp))
            Text("Limpiar", color = Tokens.colors.danger, modifier = Modifier.padding(start = 6.dp))
        }
    }
}

// Inputs

@Composable
private fun Inputs(
    client: String, onClient: (String) -> Unit,
    plantId: String?, onPlant: (String?) -> Unit, plants: List<Pair<String, String>>,
    input: CalculatorInput, onInput: (CalculatorInput) -> Unit,
    modifier: Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(20.dp)) {
        TramaCard(padding = 18.dp) {
            SectionTitle("Estilo", Icons.Filled.Checkroom)
            TramaField(client, onClient, "Cliente", leading = Icons.Filled.Groups)
            PlantPicker(plantId, plants, onPlant)
            NumberRow("Cantidad del estilo", Icons.Filled.Numbers, input.quantity, "prendas") { onInput(input.copy(quantity = it)) }
            NumberRow("Minutaje real", Icons.Filled.Timer, input.realMinutes, "min") { onInput(input.copy(realMinutes = it)) }
            NumberRow("Minutaje cliente", Icons.Filled.WatchLater, input.clientMinutes, "min") { onInput(input.copy(clientMinutes = it)) }
            NumberRow("Operarios", Icons.Filled.People, input.operators) { onInput(input.copy(operators = it)) }
            NumberRow("Precio unitario interno", Icons.Filled.LocalOffer, input.internalUnitPrice, "MXN") { onInput(input.copy(internalUnitPrice = it)) }
            NumberRow("Precio por estilo", Icons.Filled.MonetizationOn, input.pricePerStyle, "MXN") { onInput(input.copy(pricePerStyle = it)) }
            NumberRow("Gastos operativos", Icons.Filled.CreditCard, input.operatingExpenses, "MXN") { onInput(input.copy(operatingExpenses = it)) }
        }
        TramaCard(padding = 18.dp) {
            SectionTitle("Minuto real de producción", Icons.Filled.Speed)
            NumberRow("Operarios de línea", Icons.Filled.Person, input.lineOperators) { onInput(input.copy(lineOperators = it)) }
            NumberRow("Producción real diaria", Icons.AutoMirrored.Filled.ShowChart, input.realDailyProduction, "prendas") { onInput(input.copy(realDailyProduction = it)) }
        }
    }
}

@Composable
private fun SectionTitle(title: String, icon: ImageVector) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, null, tint = Tokens.colors.brand, modifier = Modifier.size(20.dp))
        Text(title, style = MaterialTheme.typography.titleMedium, color = Tokens.colors.brand)
    }
}

/** Decimal input that updates the results on every keystroke; empty means "no value". */
@Composable
private fun NumberRow(title: String, icon: ImageVector, value: Double, unit: String? = null, onChange: (Double) -> Unit) {
    var text by remember { mutableStateOf(if (value == 0.0) "" else Fmt.number(value, 4).replace(",", "")) }
    OutlinedTextField(
        value = text,
        onValueChange = { raw ->
            val cleaned = raw.replace(',', '.').filter { it.isDigit() || it == '.' }.let { s ->
                val i = s.indexOf('.')
                if (i >= 0) s.substring(0, i + 1) + s.substring(i + 1).replace(".", "") else s
            }.take(12)
            text = cleaned
            onChange(cleaned.toDoubleOrNull() ?: 0.0)
        },
        modifier = Modifier.fillMaxWidth(),
        label = { Text(title) },
        singleLine = true,
        leadingIcon = { Icon(icon, null, tint = Tokens.colors.brand) },
        suffix = unit?.let { { Text(it, color = Tokens.colors.secondary) } },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(
            unfocusedBorderColor = Tokens.colors.stroke, focusedContainerColor = Tokens.colors.surface, unfocusedContainerColor = Tokens.colors.surface,
        ),
    )
}

@Composable
private fun PlantPicker(selected: String?, plants: List<Pair<String, String>>, onSelect: (String?) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val name = plants.firstOrNull { it.first == selected }?.second ?: "Sin planta"
    Box {
        TramaField(name, {}, "Planta", leading = Icons.Filled.Apartment)
        Box(
            Modifier.matchParentSize().clip(RoundedCornerShape(14.dp)).clickable { open = true }
                .semantics { contentDescription = "Planta: $name. Toca para elegir" },
            contentAlignment = Alignment.CenterEnd,
        ) { Icon(Icons.Filled.ArrowDropDown, null, tint = Tokens.colors.secondary, modifier = Modifier.padding(end = 12.dp)) }
        DropdownMenu(open, { open = false }) {
            DropdownMenuItem({ Text("Sin planta") }, { onSelect(null); open = false })
            plants.forEach { (id, plant) -> DropdownMenuItem({ Text(plant) }, { onSelect(id); open = false }) }
        }
    }
}

// Results

@Composable
private fun Results(result: CalculatorResult, constants: CalculatorConstants, modifier: Modifier) {
    val c = Tokens.colors
    Column(modifier, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            IncomeCard("Ingreso bruto", result.grossIncome, Icons.Filled.Payments, emphasized = false, Modifier.weight(1f))
            IncomeCard("Ingreso neto", result.netIncome, Icons.AutoMirrored.Filled.TrendingUp, emphasized = true, Modifier.weight(1f))
        }
        data class Item(val title: String, val value: String?, val unit: String?, val icon: ImageVector, val tint: Color, val hint: String)
        val items = listOf(
            Item("Precio por minuto real", result.pricePerRealMinute?.let { Fmt.money(it) }, null, Icons.Filled.Timer, c.brand, "Precio por estilo ÷ minutaje real"),
            Item("Meta diaria", result.dailyGoal?.let { Fmt.number(it) }, "prendas", Icons.Filled.TrackChanges, c.info,
                if (constants.minutesPerDay <= 0) "Requiere minutos por día" else "Operarios × minutos día ÷ minutaje"),
            Item("Producción semanal", result.weeklyProduction?.let { Fmt.number(it) }, "prendas", Icons.Filled.DateRange, c.info, "Meta diaria × días por semana"),
            Item("Días estimados", result.estimatedDays?.let { Fmt.number(it) }, "días", Icons.Filled.Event, c.warning, "Cantidad ÷ meta diaria"),
            Item("Meses estimados", result.estimatedMonths?.let { Fmt.number(it, 2) }, "meses", Icons.Filled.CalendarMonth, c.warning, "Días ÷ días por mes"),
            null, // efficiency
            Item("Minuto real de producción", result.realProductionMinute?.let { Fmt.number(it, 2) }, "min", Icons.Filled.Speed, c.success, "Minutos día × operarios ÷ producción diaria"),
        )
        AdaptiveGrid(items.size, minWidth = 210.dp, spacing = 14.dp) { i, m ->
            val item = items[i]
            if (item == null) EfficiencyCard(result.minuteEfficiency, m)
            else ResultCard(item.title, item.value, item.unit, item.icon, item.tint, item.hint, m)
        }
    }
}

@Composable
private fun IncomeCard(title: String, value: Double?, icon: ImageVector, emphasized: Boolean, modifier: Modifier) {
    val c = Tokens.colors
    val shape = RoundedCornerShape(Tokens.radius)
    val content = if (emphasized) Color.White else c.ink
    val valueColor = if (emphasized && (value ?: 0.0) < 0) c.danger else content
    val text = value?.let { Fmt.money(it) } ?: "—"
    Column(
        modifier.clip(shape)
            .background(if (emphasized) Brush.linearGradient(listOf(c.brand, c.brandDeep)) else Brush.linearGradient(listOf(c.surface, c.surface)))
            .border(1.dp, c.stroke, shape)
            .semantics(mergeDescendants = true) { contentDescription = "$title: $text" }
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(icon, null, tint = content.copy(alpha = 0.85f), modifier = Modifier.size(18.dp))
            Text(title, style = MaterialTheme.typography.labelLarge, color = content.copy(alpha = 0.85f))
        }
        Text(text, fontSize = 32.sp, fontWeight = FontWeight.Bold, color = valueColor, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(if (emphasized) "Bruto − gastos operativos" else "Cantidad × precio por estilo", style = MaterialTheme.typography.bodySmall, color = content.copy(alpha = 0.7f))
    }
}

@Composable
private fun ResultCard(title: String, value: String?, unit: String?, icon: ImageVector, tint: Color, hint: String, modifier: Modifier) {
    TramaCard(modifier.semantics(mergeDescendants = true) { contentDescription = "$title: ${value?.let { v -> "$v ${unit.orEmpty()}" } ?: "sin valor"}" }, padding = 16.dp) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(11.dp)).background(tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp))
        }
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(
                value ?: "—", fontSize = 26.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                color = if (value == null) Tokens.colors.secondary.copy(alpha = 0.5f) else Tokens.colors.ink,
                modifier = Modifier.weight(1f, fill = false),
            )
            if (unit != null && value != null) Text(unit, style = MaterialTheme.typography.labelMedium, color = Tokens.colors.secondary, modifier = Modifier.padding(bottom = 4.dp))
        }
        Column {
            Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = Tokens.colors.secondary)
            Text(hint, style = MaterialTheme.typography.labelSmall, color = Tokens.colors.secondary.copy(alpha = 0.6f), maxLines = 2)
        }
    }
}

@Composable
private fun EfficiencyCard(efficiency: Double?, modifier: Modifier) {
    val c = Tokens.colors
    val tint = when {
        efficiency == null -> c.secondary
        efficiency >= 1 -> c.success
        efficiency >= 0.85 -> c.warning
        else -> c.danger
    }
    val text = efficiency?.let(Fmt::percent) ?: "—"
    TramaCard(modifier.heightIn(min = 112.dp).semantics(mergeDescendants = true) { contentDescription = "Eficiencia de minutaje: $text" }, padding = 16.dp) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(54.dp), contentAlignment = Alignment.Center) {
                ProgressRing(efficiency ?: 0.0, Modifier.size(54.dp), tint, stroke = 7.dp)
                Icon(Icons.Filled.Percent, null, tint = tint, modifier = Modifier.size(16.dp))
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(text, fontSize = 26.sp, fontWeight = FontWeight.Bold, color = if (efficiency == null) c.secondary.copy(alpha = 0.5f) else c.ink)
                Text("Eficiencia de minutaje", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = c.secondary)
                Text("Minutaje cliente ÷ real", style = MaterialTheme.typography.labelSmall, color = c.secondary.copy(alpha = 0.6f))
            }
        }
    }
}

// Constants

@Composable
private fun ConstantsBanner(onConfigure: () -> Unit) {
    val warning = Tokens.colors.warning
    TramaCard(padding = 16.dp) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(44.dp).clip(RoundedCornerShape(13.dp)).background(warning.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Tune, null, tint = warning)
            }
            Column(Modifier.weight(1f)) {
                Text("Configura las constantes de planta", style = MaterialTheme.typography.titleMedium)
                Text(
                    "Minutos por operario y días de trabajo son necesarios para la meta diaria, la producción semanal y los tiempos estimados.",
                    style = MaterialTheme.typography.bodyMedium, color = Tokens.colors.secondary,
                )
            }
            Button(onConfigure, colors = ButtonDefaults.buttonColors(containerColor = warning, contentColor = Color.White)) { Text("Configurar") }
        }
    }
}

@Composable
private fun ConstantsDialog(initial: CalculatorConstants, onDismiss: () -> Unit, onSave: (CalculatorConstants) -> Unit) {
    var c by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Constantes") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Por operario", style = MaterialTheme.typography.labelLarge, color = Tokens.colors.secondary)
                DecimalField(c.minutesPerDay, { c = c.copy(minutesPerDay = it) }, "Minutos por día")
                DecimalField(c.minutesPerWeek, { c = c.copy(minutesPerWeek = it) }, "Minutos por semana")
                DecimalField(c.minutesPerMonth, { c = c.copy(minutesPerMonth = it) }, "Minutos por mes")
                HorizontalDivider(color = Tokens.colors.stroke)
                Text("Calendario", style = MaterialTheme.typography.labelLarge, color = Tokens.colors.secondary)
                DecimalField(c.workDaysPerWeek, { c = c.copy(workDaysPerWeek = it) }, "Días de trabajo por semana")
                DecimalField(c.workDaysPerMonth, { c = c.copy(workDaysPerMonth = it) }, "Días de trabajo por mes")
                Text("Se guardan en este dispositivo y se usan en todos los cálculos.", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
            }
        },
        confirmButton = { TextButton({ onSave(c) }) { Text("Guardar") } },
        dismissButton = { TextButton(onDismiss) { Text("Cancelar") } },
    )
}

/** Plain-text summary for the clipboard / share sheet (same lines as iOS). */
fun calculatorSummary(client: String, plant: String?, input: CalculatorInput, result: CalculatorResult): String {
    fun money(v: Double?) = v?.let { Fmt.money(it) } ?: "—"
    fun num(v: Double?, unit: String) = v?.let { "${Fmt.number(it)} $unit" } ?: "—"
    val lines = mutableListOf("Cálculo de producción · Trama")
    if (client.isNotEmpty()) lines += "Cliente: $client"
    if (plant != null) lines += "Planta: $plant"
    lines += listOf(
        "Cantidad: ${Fmt.int(input.quantity.toInt())} prendas · Minutaje real ${Fmt.number(input.realMinutes, 2)} · cliente ${Fmt.number(input.clientMinutes, 2)}",
        "Operarios: ${Fmt.int(input.operators.toInt())} · Precio por estilo ${Fmt.money(input.pricePerStyle)} · Gastos ${Fmt.money(input.operatingExpenses)}",
        "",
        "Ingreso bruto: ${money(result.grossIncome)}",
        "Ingreso neto: ${money(result.netIncome)}",
        "Precio por minuto real: ${money(result.pricePerRealMinute)}",
        "Meta diaria: ${num(result.dailyGoal, "prendas")}",
        "Producción semanal: ${num(result.weeklyProduction, "prendas")}",
        "Días estimados: ${num(result.estimatedDays, "días")}",
        "Meses estimados: ${num(result.estimatedMonths, "meses")}",
        "Eficiencia de minutaje: ${result.minuteEfficiency?.let(Fmt::percent) ?: "—"}",
        "Minuto real de producción: ${num(result.realProductionMinute, "min")}",
    )
    return lines.joinToString("\n")
}
