package com.nevutech.trama.core.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.nevutech.trama.core.domain.CalculatorConstants
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "trama_settings")

/** Small key-value preferences (the iOS app uses UserDefaults / @AppStorage for the same keys). */
class SettingsStore(private val store: DataStore<Preferences>) {
    constructor(context: Context) : this(context.dataStore)

    private object Keys {
        val session = stringPreferencesKey("session.userID")
        val urgency = intPreferencesKey("settings.urgencyWindowDays")
        val company = stringPreferencesKey("company.name")
        val demoSeeded = booleanPreferencesKey("demo.seeded")
        val legacyUrl = stringPreferencesKey("legacy.baseURL")
        val minutesPerDay = doublePreferencesKey("minutos_dia_operario")
        val minutesPerWeek = doublePreferencesKey("minutos_semana_operario")
        val minutesPerMonth = doublePreferencesKey("minutos_mes_operario")
        val daysPerMonth = doublePreferencesKey("dias_mes")
        val daysPerWeek = doublePreferencesKey("dias_semana")
    }

    val urgencyWindowDays: Flow<Int> = store.data.map { it[Keys.urgency] ?: 7 }
    val companyName: Flow<String> = store.data.map { it[Keys.company].orEmpty() }
    val demoSeeded: Flow<Boolean> = store.data.map { it[Keys.demoSeeded] ?: false }
    val legacyBaseUrl: Flow<String> = store.data.map { it[Keys.legacyUrl].orEmpty() }
    val calculatorConstants: Flow<CalculatorConstants> = store.data.map {
        CalculatorConstants(
            minutesPerDay = it[Keys.minutesPerDay] ?: 0.0,
            minutesPerWeek = it[Keys.minutesPerWeek] ?: 0.0,
            minutesPerMonth = it[Keys.minutesPerMonth] ?: 0.0,
            workDaysPerWeek = it[Keys.daysPerWeek] ?: 0.0,
            workDaysPerMonth = it[Keys.daysPerMonth] ?: 0.0,
        )
    }

    suspend fun sessionUserId(): String? = store.data.first()[Keys.session]
    suspend fun setSessionUserId(id: String?) = store.edit { if (id == null) it.remove(Keys.session) else it[Keys.session] = id }
    suspend fun setUrgencyWindowDays(days: Int) = store.edit { it[Keys.urgency] = days.coerceIn(1, 30) }
    suspend fun setCompanyName(name: String) = store.edit { it[Keys.company] = name.trim() }
    suspend fun setDemoSeeded(value: Boolean) = store.edit { it[Keys.demoSeeded] = value }
    suspend fun setLegacyBaseUrl(url: String) = store.edit { it[Keys.legacyUrl] = url.trim() }
    suspend fun setCalculatorConstants(c: CalculatorConstants) = store.edit {
        it[Keys.minutesPerDay] = c.minutesPerDay
        it[Keys.minutesPerWeek] = c.minutesPerWeek
        it[Keys.minutesPerMonth] = c.minutesPerMonth
        it[Keys.daysPerWeek] = c.workDaysPerWeek
        it[Keys.daysPerMonth] = c.workDaysPerMonth
    }
}
