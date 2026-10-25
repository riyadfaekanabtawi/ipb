package com.nevutech.trama.feature.plants

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.app.LocalNavigator
import com.nevutech.trama.app.rememberGraph
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.designsystem.CapacityBar
import com.nevutech.trama.designsystem.Tokens
import com.nevutech.trama.designsystem.TramaCard
import com.nevutech.trama.designsystem.TramaScreen
import com.nevutech.trama.designsystem.capacityTint
import com.nevutech.trama.feature.production.CalendarEvent
import com.nevutech.trama.feature.production.CalendarMath
import com.nevutech.trama.feature.production.FilterMenuChip
import com.nevutech.trama.feature.production.IconTile
import com.nevutech.trama.feature.production.ScreenHeader
import com.nevutech.trama.feature.production.isWideLayout
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

private val dayTitleFormat = DateTimeFormatter.ofPattern("EEEE d 'de' MMMM", Fmt.locale)
private val fullDayFormat = DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(Fmt.locale)

/** Month calendar of production starts and client deliveries, with each plant's capacity for the month. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun PlantCalendarScreen() {
    val graph by rememberGraph()
    val navigator = LocalNavigator.current
    val wide = isWideLayout()
    val sidePanel = isWideLayout(900)

    var monthText by rememberSaveable { mutableStateOf(YearMonth.now().toString()) }
    val month = YearMonth.parse(monthText)
    var plantId by rememberSaveable { mutableStateOf<String?>(null) }
    var selectedText by rememberSaveable { mutableStateOf<String?>(null) }
    val selected = selectedText?.let(LocalDate::parse)
    var direction by remember { mutableStateOf(1) }

    fun shift(months: Long) {
        direction = if (months > 0) 1 else -1
        monthText = month.plusMonths(months).toString()
        selectedText = null
    }

    val events = CalendarEvent.forMonth(graph, month, plantId)
    val byDay = events.groupBy { it.date }
    val plants = graph.plants.sortedBy { it.name.lowercase() }
    val shown = plants.filter { plantId == null || it.id == plantId }

    val openEvent: (CalendarEvent) -> Unit = { e ->
        if (e.kind == CalendarEvent.Kind.Production) navigator.openAssignment(e.targetId) else navigator.openOrder(e.targetId)
    }

    TramaScreen {
        Row(Modifier.fillMaxSize()) {
            Column(Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                ScreenHeader("Calendario de plantas", showTitle = wide)
                Column(Modifier.padding(horizontal = if (wide) 24.dp else 16.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    // Month header
                    FlowRow(
                        Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp),
                        itemVerticalAlignment = Alignment.CenterVertically,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton({ shift(-1) }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Mes anterior") }
                            AnimatedContent(month, transitionSpec = {
                                slideInHorizontally { it * direction / 2 } togetherWith slideOutHorizontally { -it * direction / 2 }
                            }, label = "month") { m ->
                                Text(
                                    Fmt.monthYear(m.atDay(1)), fontSize = if (wide) 30.sp else 24.sp, fontWeight = FontWeight.Bold,
                                    modifier = Modifier.width(if (wide) 260.dp else 200.dp),
                                )
                            }
                            IconButton({ shift(1) }) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Mes siguiente") }
                        }
                        OutlinedButton({ direction = 1; monthText = YearMonth.now().toString(); selectedText = null }) { Text("Hoy") }
                        FilterMenuChip(
                            graph.plant(plantId)?.name ?: "Todas las plantas", Icons.Filled.Apartment, plantId != null,
                            listOf<Pair<String, () -> Unit>>("Todas las plantas" to { plantId = null }) + plants.map { p -> p.name to { plantId = p.id } },
                        )
                    }

                    // Capacity per plant
                    BoxWithConstraints {
                        val columns = maxOf(1, (maxWidth / 260.dp).toInt())
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            shown.chunked(columns).forEach { row ->
                                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                                    row.forEach { plant ->
                                        val ledger = graph.ledger(plant)
                                        val used = ledger.used(month)
                                        val utilization = ledger.utilization(month)
                                        TramaCard(Modifier.weight(1f), padding = 16.dp) {
                                            Row {
                                                Text(plant.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f), maxLines = 1)
                                                Text(Fmt.percent(utilization), fontWeight = FontWeight.Bold, color = capacityTint(utilization.toFloat()))
                                            }
                                            CapacityBar(used, plant.maxCapacity)
                                            Row {
                                                Text("Usada ${Fmt.money(used, compact = true)}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary, modifier = Modifier.weight(1f))
                                                Text("Disponible ${Fmt.money(maxOf(0.0, plant.maxCapacity - used), compact = true)}", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                                            }
                                        }
                                    }
                                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                                }
                            }
                        }
                    }

                    // Month grid; horizontal swipes change month.
                    TramaCard(
                        Modifier.pointerInput(monthText) {
                            var total = 0f
                            detectHorizontalDragGestures(onDragStart = { total = 0f }, onDragEnd = {
                                if (total < -120f) shift(1) else if (total > 120f) shift(-1)
                            }) { _, delta -> total += delta }
                        },
                        padding = if (wide) 16.dp else 8.dp,
                    ) {
                        MonthGrid(month, byDay, selected, wide) { day -> selectedText = if (selected == day) null else day.toString() }
                    }

                    FlowRow(horizontalArrangement = Arrangement.spacedBy(20.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.ContentCut, null, tint = Tokens.colors.secondary, modifier = Modifier.size(14.dp))
                            Text(" Inicio de producción (color por planta)", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Flag, null, tint = Tokens.colors.danger, modifier = Modifier.size(14.dp))
                            Text(" Entrega al cliente", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.danger)
                        }
                    }
                }
            }
            if (sidePanel) {
                AnimatedVisibility(selected != null) {
                    val day = selected ?: return@AnimatedVisibility
                    Surface(
                        Modifier.width(340.dp).fillMaxHeight(), color = Tokens.colors.surfaceRaised,
                        border = BorderStroke(1.dp, Tokens.colors.stroke),
                    ) {
                        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Spacer(Modifier.weight(1f))
                                IconButton({ selectedText = null }) { Icon(Icons.Filled.Close, "Cerrar") }
                            }
                            DayEvents(day, byDay[day].orEmpty(), openEvent)
                        }
                    }
                }
            }
        }
    }

    if (!sidePanel && selected != null) {
        ModalBottomSheet({ selectedText = null }, containerColor = Tokens.colors.canvas) {
            Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp).padding(bottom = 24.dp)) {
                DayEvents(selected, byDay[selected].orEmpty()) { selectedText = null; openEvent(it) }
            }
        }
    }
}

@Composable
private fun MonthGrid(month: YearMonth, byDay: Map<LocalDate, List<CalendarEvent>>, selected: LocalDate?, wide: Boolean, onSelect: (LocalDate) -> Unit) {
    val days = CalendarMath.gridDays(month)
    val today = LocalDate.now()
    val gap = if (wide) 8.dp else 4.dp
    Column(verticalArrangement = Arrangement.spacedBy(gap)) {
        Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
            CalendarMath.weekdaySymbols().forEach {
                Text(
                    it.uppercase(Fmt.locale), Modifier.weight(1f), style = MaterialTheme.typography.labelSmall, color = Tokens.colors.secondary,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
            }
        }
        BoxWithConstraints {
            val compact = (maxWidth - gap * 6) / 7 < 96.dp
            Column(verticalArrangement = Arrangement.spacedBy(gap)) {
                days.chunked(7).forEach { week ->
                    Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                        week.forEach { day ->
                            if (day == null) Spacer(Modifier.weight(1f))
                            else DayCell(day, byDay[day].orEmpty(), day == today, day == selected, compact, Modifier.weight(1f)) { onSelect(day) }
                        }
                        repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun eventTint(e: CalendarEvent): Color =
    if (e.kind == CalendarEvent.Kind.Delivery) Tokens.colors.danger else Tokens.accent(e.plantName.orEmpty())

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DayCell(day: LocalDate, events: List<CalendarEvent>, isToday: Boolean, isSelected: Boolean, compact: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Tokens.colors
    val shape = RoundedCornerShape(if (compact) 8.dp else 12.dp)
    Column(
        modifier.heightIn(min = if (compact) 64.dp else 110.dp).clip(shape)
            .background(if (isSelected) c.brand.copy(alpha = 0.12f) else c.surfaceRaised)
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) c.brand else c.stroke, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = "${day.format(fullDayFormat)}, ${events.size} eventos" }
            .padding(if (compact) 3.dp else 6.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier.size(if (compact) 22.dp else 28.dp).clip(CircleShape).background(if (isToday) c.brand else Color.Transparent),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "${day.dayOfMonth}", style = MaterialTheme.typography.bodyMedium, fontWeight = if (isToday) FontWeight.Bold else FontWeight.Medium,
                color = if (isToday) Color.White else c.ink, fontSize = if (compact) 12.sp else 15.sp,
            )
        }
        val limit = 3
        if (compact) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(2.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                events.take(limit).forEach { e ->
                    Icon(if (e.kind == CalendarEvent.Kind.Delivery) Icons.Filled.Flag else Icons.Filled.ContentCut, null, tint = eventTint(e), modifier = Modifier.size(12.dp))
                }
            }
        } else {
            events.take(limit).forEach { e ->
                val tint = eventTint(e)
                Row(
                    Modifier.fillMaxWidth().background(tint.copy(alpha = 0.14f), RoundedCornerShape(6.dp)).padding(horizontal = 6.dp, vertical = 3.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(if (e.kind == CalendarEvent.Kind.Delivery) Icons.Filled.Flag else Icons.Filled.ContentCut, null, tint = tint, modifier = Modifier.size(10.dp))
                    Text(" ${e.title}", color = tint, style = MaterialTheme.typography.labelSmall, maxLines = 1)
                }
            }
        }
        if (events.size > limit) Text("+${events.size - limit} más", style = MaterialTheme.typography.labelSmall, color = c.secondary, maxLines = 1)
    }
}

@Composable
private fun DayEvents(day: LocalDate, events: List<CalendarEvent>, onOpen: (CalendarEvent) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(day.format(dayTitleFormat).replaceFirstChar { it.titlecase(Fmt.locale) }, style = MaterialTheme.typography.titleLarge)
        if (events.isEmpty()) Text("Sin producción ni entregas este día.", color = Tokens.colors.secondary)
        events.forEach { e ->
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable { onOpen(e) }.padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                IconTile(if (e.kind == CalendarEvent.Kind.Delivery) Icons.Filled.Flag else Icons.Filled.ContentCut, eventTint(e), 32.dp)
                Column(Modifier.weight(1f)) {
                    Text(e.title, style = MaterialTheme.typography.titleMedium)
                    Text(e.subtitle, style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Tokens.colors.secondary.copy(alpha = 0.5f))
            }
        }
    }
}
