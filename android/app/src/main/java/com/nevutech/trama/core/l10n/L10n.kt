package com.nevutech.trama.core.l10n

import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import androidx.annotation.PluralsRes
import androidx.annotation.StringRes
import com.nevutech.trama.core.domain.Fmt
import java.util.Locale

/**
 * Languages the app ships. Spanish (Mexico) is the default resource set (`values/`), so any other
 * device language falls back to it. [tag] is the BCP-47 tag stored by the per-app language setting.
 */
enum class AppLanguage(val tag: String?) {
    System(null),
    Spanish("es-MX"),
    English("en"),
    Portuguese("pt-BR");

    companion object {
        fun fromTag(tag: String?): AppLanguage = when (tag?.substringBefore('-')?.substringBefore('_')?.lowercase()) {
            null, "" -> System
            "es" -> Spanish
            "en" -> English
            "pt" -> Portuguese
            else -> System
        }
    }
}

/**
 * Per-app language and string lookup for code outside Compose (services, sync messages, toasts,
 * WorkManager). Compose code uses `stringResource`; both read the same resources.
 *
 * Android 13+ stores the choice in the platform (Settings → Apps → Trama → Language, and
 * [LocaleManager]); older versions keep it in a private preference applied in
 * `MainActivity.attachBaseContext`.
 */
object L10n {
    private const val PREFS = "trama_locale"
    private const val KEY = "app.language"

    @Volatile private var app: Context? = null
    @Volatile private var cached: Pair<String, Context>? = null

    fun init(context: Context) {
        app = context.applicationContext
        cached = null
        Fmt.locale = formattingLocale()
    }

    /** The language picked in Ajustes (or the Android 13+ app language setting). */
    fun language(context: Context = requireApp()): AppLanguage = AppLanguage.fromTag(storedTag(context))

    /**
     * Applies [language] app-wide. On Android 13+ the platform recreates the activities; on older
     * versions the caller recreates the activity (see `MainActivity`).
     */
    fun setLanguage(context: Context, language: AppLanguage) {
        val ctx = context.applicationContext
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, language.tag).apply()
        cached = null
        if (Build.VERSION.SDK_INT >= 33) {
            ctx.getSystemService(LocaleManager::class.java).applicationLocales =
                language.tag?.let { LocaleList.forLanguageTags(it) } ?: LocaleList.getEmptyLocaleList()
        }
        Fmt.locale = formattingLocale()
    }

    /**
     * Switches the language from the in-app picker. Android 13+ recreates the activity itself;
     * older versions need an explicit recreate to pick up [wrap].
     */
    fun apply(activity: android.app.Activity, language: AppLanguage) {
        if (language == language(activity)) return
        setLanguage(activity, language)
        if (Build.VERSION.SDK_INT < 33) activity.recreate()
    }

    /** Re-reads the locale after a configuration change (e.g. device language changed). */
    fun refresh() {
        cached = null
        Fmt.locale = formattingLocale()
    }

    /** Locale the UI is shown in: the explicit choice, or the device language. */
    fun currentLocale(context: Context = requireApp()): Locale =
        storedTag(context)?.let(Locale::forLanguageTag)
            ?: context.applicationContext.resources.configuration.locales[0]

    /**
     * Locale for dates and numbers: the UI locale when it is one we translate (keeping the
     * device region, e.g. en-GB), otherwise Spanish (Mexico) to match the fallback strings.
     */
    fun formattingLocale(context: Context? = app): Locale {
        val locale = context?.let { currentLocale(it) } ?: return Fmt.DEFAULT_LOCALE
        return when (locale.language) {
            "es", "en" -> locale
            "pt" -> if (locale.country.isEmpty()) Locale.forLanguageTag("pt-BR") else locale
            else -> Fmt.DEFAULT_LOCALE
        }
    }

    /** `Accept-Language` value for API calls, e.g. "es-MX", "en", "pt-BR". */
    fun acceptLanguage(): String {
        val ctx = app ?: return "es-MX"
        val locale = currentLocale(ctx)
        return when (locale.language) {
            "en" -> if (locale.country.isEmpty()) "en" else locale.toLanguageTag()
            "pt" -> "pt-BR"
            else -> "es-MX"
        }
    }

    /** Wraps [base] so its resources use the stored language (Android 12 and older). */
    fun wrap(base: Context): Context {
        if (Build.VERSION.SDK_INT >= 33) return base
        val tag = storedTag(base) ?: return base
        return base.createConfigurationContext(Configuration(base.resources.configuration).apply { setLocale(Locale.forLanguageTag(tag)) })
    }

    fun str(@StringRes id: Int): String = resources()?.getString(id) ?: fallback(id)

    fun str(@StringRes id: Int, vararg args: Any): String = resources()?.getString(id, *args) ?: fallback(id)

    fun plural(@PluralsRes id: Int, count: Int, vararg args: Any): String =
        resources()?.getQuantityString(id, count, *(if (args.isEmpty()) arrayOf<Any>(count) else args)) ?: fallback(id)

    private fun fallback(id: Int) = "#$id"

    private fun resources(): android.content.res.Resources? {
        val ctx = app ?: return null
        val tag = storedTag(ctx) ?: return ctx.resources
        cached?.let { (t, c) -> if (t == tag) return c.resources }
        val localized = ctx.createConfigurationContext(Configuration(ctx.resources.configuration).apply { setLocale(Locale.forLanguageTag(tag)) })
        cached = tag to localized
        return localized.resources
    }

    private fun storedTag(context: Context): String? {
        if (Build.VERSION.SDK_INT >= 33) {
            val locales = runCatching { context.getSystemService(LocaleManager::class.java)?.applicationLocales }.getOrNull()
            if (locales != null && !locales.isEmpty) return locales[0].toLanguageTag()
            // The platform setting wins over a stale preference (e.g. reset from system settings).
            if (locales != null) return null
        }
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
    }

    private fun requireApp(): Context = checkNotNull(app) { "L10n.init was not called" }
}
