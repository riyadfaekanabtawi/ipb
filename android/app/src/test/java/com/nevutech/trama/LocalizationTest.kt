package com.nevutech.trama

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.CatalogErrors
import com.nevutech.trama.core.data.CatalogKind
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.sync.DeviceInfo
import com.nevutech.trama.core.data.sync.TramaApi
import com.nevutech.trama.core.domain.AppSection
import com.nevutech.trama.core.domain.AssignmentError
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.l10n.AppLanguage
import com.nevutech.trama.core.l10n.L10n
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.first
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate

/** Resources, formatting, demo data and API headers in each shipped language. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LocalizationTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val day = LocalDate.of(2026, 3, 9)

    @After fun resetLanguage() {
        L10n.setLanguage(context, AppLanguage.System)
    }

    @Test fun spanishIsTheDefault() {
        assertEquals("Gerente de cortes", Role.CutManager.title)
        assertEquals("Cortes por asignar", AppSection.Orders.title)
        assertEquals("Escribe el nombre de la planta.", CatalogErrors.emptyName(CatalogKind.Plant))
        assertEquals("$1,234.50", Fmt.money(1234.5))
        assertEquals("9 mar 2026", Fmt.date(day).replace(".", ""))
        assertEquals("En 3 días", Fmt.relativeDays(3))
        assertEquals("Vencido hace 2 días", Fmt.relativeDays(-2))
        assertEquals("es-MX", L10n.acceptLanguage())
    }

    @Test @Config(qualifiers = "en")
    fun englishStringsAndFormats() {
        assertEquals("Cutting Manager", Role.CutManager.title)
        assertEquals("Cuts to assign", AppSection.Orders.title)
        assertEquals("Ready for sewing", CutStatus.Ready.title)
        assertEquals("Enter the plant name.", CatalogErrors.emptyName(CatalogKind.Plant))
        assertEquals("Pick a date on the calendar.", AssignmentError.MissingDate.message)
        assertEquals("MX$1,234.50", Fmt.money(1234.5))
        assertEquals("MX$1.5 M", Fmt.money(1_500_000.0, compact = true))
        assertEquals("1,234", Fmt.int(1234))
        assertEquals("45%", Fmt.percent(0.459))
        assertEquals("Mar 9, 2026", Fmt.date(day))
        assertEquals("Due tomorrow", Fmt.relativeDays(1))
        assertEquals("In 3 days", Fmt.relativeDays(3))
        assertEquals("Overdue by 4 days", Fmt.relativeDays(-4))
        assertEquals("en", L10n.acceptLanguage())
        val summary = BackupService.Summary(null, null, listOf(BackupService.Count(R.string.backup_count_plants, R.plurals.backup_count_plants, 1)))
        assertEquals("1 plant", L10n.plural(summary.items[0].plural, 1, 1))
        assertEquals(listOf("Plants" to 1), summary.counts)
    }

    @Test @Config(qualifiers = "pt-rBR")
    fun brazilianPortugueseStringsAndFormats() {
        assertEquals("Gerente de Unidade", Role.PlantManager.title)
        assertEquals("Expedições urgentes", AppSection.Shipments.title)
        assertEquals("Cadastros", AppSection.Group.Catalogs.title)
        assertEquals("MX$ 1.234,50", Fmt.money(1234.5).replace(' ', ' '))
        assertEquals("1.234", Fmt.int(1234))
        assertEquals("Em 3 dias", Fmt.relativeDays(3))
        assertEquals("março de 2026", Fmt.monthYear(day).lowercase())
        assertEquals("pt-BR", L10n.acceptLanguage())
    }

    @Test @Config(qualifiers = "pt-rPT")
    fun anyPortugueseFallsBackToBrazilian() {
        assertEquals("Gerente de Unidade", Role.PlantManager.title)
        assertEquals("pt-BR", L10n.acceptLanguage())
    }

    @Test @Config(qualifiers = "fr")
    fun otherLanguagesFallBackToSpanish() {
        assertEquals("Gerente de cortes", Role.CutManager.title)
        assertEquals("$1,234.50", Fmt.money(1234.5))
        assertEquals("es-MX", L10n.acceptLanguage())
    }

    @Test fun inAppLanguageOverridesTheDevice() {
        L10n.setLanguage(context, AppLanguage.English)
        assertEquals(AppLanguage.English, L10n.language(context))
        assertEquals("Shipping Manager", Role.ShippingManager.title)
        assertEquals("MX$1,234.50", Fmt.money(1234.5))
        assertEquals("en", L10n.acceptLanguage())
        L10n.setLanguage(context, AppLanguage.Portuguese)
        assertEquals("Gerente de Expedição", Role.ShippingManager.title)
        L10n.setLanguage(context, AppLanguage.System)
        assertEquals(AppLanguage.System, L10n.language(context))
        assertEquals("Gerente de envíos", Role.ShippingManager.title)
    }

    @Test @Config(qualifiers = "en")
    fun demoDataIsSeededInTheCurrentLanguage() = runBlocking {
        val db = TramaDatabase.inMemory(context)
        DemoSeeder.seed(db, day)
        val plants = db.dao().plants().first().map { it.name }
        assertTrue(plants.toString(), "North Plant" in plants)
        val orders = db.dao().orders().first()
        assertTrue(orders.any { it.garment == "Skirt" })
        // Raw values never change with the language.
        val users = db.dao().users().first()
        assertTrue(users.any { it.role == "Gerente de Cortes" })
        assertEquals("Demo Textiles", DemoSeeder.DEMO_COMPANY)
        db.close()
    }

    @Test @Config(qualifiers = "pt-rBR")
    fun apiRequestsSendTheAppLanguage() = runBlocking {
        FakePlatform().use { platform ->
            TramaApi { platform.baseUrl }.login("admin@empresa.mx", "x", DeviceInfo("d", "android", "Pixel"))
            assertEquals(listOf<String?>("pt-BR"), platform.languages)
        }
    }
}
