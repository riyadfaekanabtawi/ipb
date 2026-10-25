package com.nevutech.trama.core.domain

import com.nevutech.trama.R
import com.nevutech.trama.core.l10n.L10n
import java.math.RoundingMode
import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Currency
import java.util.Locale

/**
 * Formatting shared by every screen, in the app's current locale (see [L10n.formattingLocale]).
 * Amounts are always Mexican pesos (MXN); only the number style follows the locale.
 */
object Fmt {
    val DEFAULT_LOCALE: Locale = Locale.forLanguageTag("es-MX")
    private val MXN: Currency = Currency.getInstance("MXN")

    /** Set by [L10n] at start-up and when the language changes. */
    @Volatile var locale: Locale = DEFAULT_LOCALE

    private val isEnglish get() = locale.language == "en"

    private fun shortDateFormat() = DateTimeFormatter.ofPattern(if (isEnglish) "MMM d" else "d MMM", locale)
    private fun longDateFormat() = DateTimeFormatter.ofPattern(if (isEnglish) "MMM d, yyyy" else "d MMM yyyy", locale)
    private fun monthYearFormat() = DateTimeFormatter.ofPattern(if (locale.language == "pt") "MMMM 'de' yyyy" else "MMMM yyyy", locale)

    fun int(value: Int): String = NumberFormat.getIntegerInstance(locale).format(value)
    fun int(value: Long): String = NumberFormat.getIntegerInstance(locale).format(value)

    fun number(value: Double, digits: Int = 1): String =
        NumberFormat.getNumberInstance(locale).apply { maximumFractionDigits = digits }.format(value)

    /** Peso symbol as written in the current locale ("$" in Mexico, "MX$" elsewhere). */
    val currencySymbol: String get() = if (locale.country == "MX") "$" else MXN.getSymbol(locale)

    fun money(value: Double, compact: Boolean = false): String {
        if (compact && kotlin.math.abs(value) >= 10_000) {
            val (scaled, suffix) = when {
                kotlin.math.abs(value) >= 1_000_000 -> value / 1_000_000 to " M"
                else -> value / 1_000 to " k"
            }
            // Keep the symbol where the locale puts it ("$1.2 M", "MX$ 1,2 M", "1,2 M MXN").
            val prefix = (currency(0) as? java.text.DecimalFormat)?.positivePrefix ?: currencySymbol
            val sign = if (value < 0) "-" else ""
            val digits = number(kotlin.math.abs(scaled), 1) + suffix
            return if (prefix.isNotBlank()) sign + prefix + digits else "$sign$digits $currencySymbol"
        }
        val digits = if (value % 1.0 == 0.0) 0 else 2
        return currency(digits).format(value)
    }

    private fun currency(digits: Int): NumberFormat = NumberFormat.getCurrencyInstance(locale).apply {
        currency = MXN
        minimumFractionDigits = digits
        maximumFractionDigits = digits
        (this as? java.text.DecimalFormat)?.let { format ->
            format.decimalFormatSymbols = format.decimalFormatSymbols.apply { currencySymbol = this@Fmt.currencySymbol }
        }
    }

    /** Whole percent, truncated like the iPad app (0.999 → "99%"). */
    fun percent(value: Double): String = NumberFormat.getPercentInstance(locale).apply {
        maximumFractionDigits = 0
        roundingMode = RoundingMode.DOWN
    }.format(value)

    fun date(value: LocalDate?): String = value?.format(longDateFormat()) ?: "—"
    fun shortDate(value: LocalDate?): String = value?.format(shortDateFormat()) ?: "—"
    fun monthYear(value: LocalDate): String = value.format(monthYearFormat()).replaceFirstChar { it.titlecase(locale) }

    fun relativeDays(days: Int?): String = when {
        days == null -> L10n.str(R.string.fmt_no_date)
        days < -1 -> L10n.plural(R.plurals.fmt_overdue_days, -days, -days)
        days == -1 -> L10n.str(R.string.fmt_due_yesterday)
        days == 0 -> L10n.str(R.string.fmt_due_today)
        days == 1 -> L10n.str(R.string.fmt_due_tomorrow)
        else -> L10n.plural(R.plurals.fmt_in_days, days, days)
    }
}
