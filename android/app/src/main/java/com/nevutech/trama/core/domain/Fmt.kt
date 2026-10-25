package com.nevutech.trama.core.domain

import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Formatting shared by every screen. Spanish (Mexico), money in MXN. */
object Fmt {
    val locale: Locale = Locale.forLanguageTag("es-MX")
    private val shortDate = DateTimeFormatter.ofPattern("d MMM", locale)
    private val longDate = DateTimeFormatter.ofPattern("d MMM yyyy", locale)
    private val monthYear = DateTimeFormatter.ofPattern("MMMM yyyy", locale)

    fun int(value: Int): String = NumberFormat.getIntegerInstance(locale).format(value)
    fun int(value: Long): String = NumberFormat.getIntegerInstance(locale).format(value)

    fun number(value: Double, digits: Int = 1): String =
        NumberFormat.getNumberInstance(locale).apply { maximumFractionDigits = digits }.format(value)

    fun money(value: Double, compact: Boolean = false): String {
        if (compact && kotlin.math.abs(value) >= 10_000) {
            val (scaled, suffix) = when {
                kotlin.math.abs(value) >= 1_000_000 -> value / 1_000_000 to " M"
                else -> value / 1_000 to " k"
            }
            return "$" + number(scaled, 1) + suffix
        }
        val digits = if (value % 1.0 == 0.0) 0 else 2
        return "$" + NumberFormat.getNumberInstance(locale).apply {
            minimumFractionDigits = digits
            maximumFractionDigits = digits
        }.format(value)
    }

    fun percent(value: Double): String = "${(value * 100).toInt()}%"

    fun date(value: LocalDate?): String = value?.format(longDate) ?: "—"
    fun shortDate(value: LocalDate?): String = value?.format(shortDate) ?: "—"
    fun monthYear(value: LocalDate): String = value.format(monthYear).replaceFirstChar { it.titlecase(locale) }

    fun relativeDays(days: Int?): String = when {
        days == null -> "Sin fecha"
        days < -1 -> "Vencido hace ${-days} días"
        days == -1 -> "Venció ayer"
        days == 0 -> "Vence hoy"
        days == 1 -> "Vence mañana"
        else -> "En $days días"
    }
}
