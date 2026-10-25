package com.nevutech.trama

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.core.app.ApplicationProvider
import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.CatalogService
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.SettingsStore
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.sync.ApiException
import com.nevutech.trama.core.data.sync.DeviceInfo
import com.nevutech.trama.core.data.sync.OfflineException
import com.nevutech.trama.core.data.sync.READ_ONLY_MARKER
import com.nevutech.trama.core.data.sync.SecretBox
import com.nevutech.trama.core.data.sync.SyncCodec
import com.nevutech.trama.core.data.sync.SyncEngine
import com.nevutech.trama.core.data.sync.SyncPrefs
import com.nevutech.trama.core.data.sync.TramaApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.jsonPrimitive
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.time.LocalDate
import java.util.UUID

/** API client and SyncEngine against an in-process fake of platform/. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SyncNetworkTest {
    /** Test stand-in for the Keystore: reversible, but never stores the plain token. */
    private class XorBox : SecretBox {
        override fun seal(plain: ByteArray) = plain.map { (it.toInt() xor 0x5A).toByte() }.toByteArray()
        override fun open(sealed: ByteArray) = seal(sealed)
    }

    private lateinit var context: Context
    private lateinit var db: TramaDatabase
    private lateinit var images: ImageStore
    private lateinit var settings: SettingsStore
    private lateinit var prefs: SyncPrefs
    private lateinit var platform: FakePlatform
    private lateinit var engine: SyncEngine
    private lateinit var tmp: File
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val messages = mutableListOf<Pair<String, Boolean>>()

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        db = TramaDatabase.inMemory(context)
        images = ImageStore(context).also { it.clear() }
        tmp = File(context.cacheDir, "sync-test-${UUID.randomUUID()}").apply { mkdirs() }
        settings = SettingsStore(PreferenceDataStoreFactory.create(scope = scope) { File(tmp, "settings.preferences_pb") })
        prefs = SyncPrefs(PreferenceDataStoreFactory.create(scope = scope) { File(tmp, "sync.preferences_pb") }, XorBox())
        platform = FakePlatform()
        engine = SyncEngine(
            db, images, prefs, TramaApi { platform.baseUrl }, settings, scope, "Pixel Tablet",
            backupDir = File(tmp, "backups"), notify = { m, e -> synchronized(messages) { messages += m to e } }, autoSyncAfterWrites = false,
        )
    }

    @After fun tearDown() {
        platform.close()
        scope.cancel()
        db.close()
        tmp.deleteRecursively()
    }

    private fun blocking(block: suspend CoroutineScope.() -> Unit): Unit = runBlocking { block() }

    private fun iso(ms: Long) = BackupService.formatDate(ms)

    private fun plantData(id: String, name: String, updated: Long) =
        SyncCodec.encode(com.nevutech.trama.core.data.PlantEntity(id = id, name = name, maxCapacity = 1000.0, createdAt = updated, updatedAt = updated))

    @Test fun apiParsesResponsesAndServerErrors() = blocking {
        val api = TramaApi { platform.baseUrl }
        val device = DeviceInfo(UUID.randomUUID().toString(), "android", "Pixel")
        val auth = api.login("admin@empresa.mx", "x", device)
        assertEquals("Textiles Nube", auth.tenant.name)
        assertTrue(auth.licence.writable)

        platform.loginError = 403 to ("plan_web_only" to "Tu plan es Web: entra desde el navegador o cambia a un plan con apps.")
        val error = runCatching { api.login("admin@empresa.mx", "x", device) }.exceptionOrNull() as ApiException
        assertEquals(403, error.status)
        assertEquals("plan_web_only", error.code)
        assertEquals("Tu plan es Web: entra desde el navegador o cambia a un plan con apps.", error.message)

        val unauthorized = runCatching { api.pull("wrong", 0) }.exceptionOrNull() as ApiException
        assertEquals(401, unauthorized.status)

        val offline = runCatching { TramaApi { "http://127.0.0.1:1/api" }.pull("t", 0) }.exceptionOrNull()
        assertTrue("got $offline", offline is OfflineException)
    }

    @Test fun signInLinksDeviceReplacingDemoDataAndKeepsOfflineLogin() = blocking {
        DemoSeeder.seed(db, LocalDate.of(2026, 10, 1))
        settings.setDemoSeeded(true)
        val plant = "0f8b5c34-38a5-4d3c-b2a8-0e1d5f6a7b01"
        platform.put("plants", plant, iso(1_760_000_000_000), plantData(plant, "Planta Nube", 1_760_000_000_000))
        platform.put("users", platform.userId, "2026-10-01T00:00:00.000Z", platform.userData)

        val user = engine.signIn(" Admin@Empresa.mx ", "secreta")

        assertEquals(platform.userId, user.id)
        assertEquals("hash", user.passwordHash)
        assertEquals(listOf("Planta Nube"), db.dao().plants().first().map { it.name })
        assertNull("demo data is never uploaded", db.dao().userByEmail("admin@demo.local"))
        assertTrue(platform.pushes.isEmpty())
        assertEquals(platform.version, engine.store.cursor())
        assertFalse(settings.demoSeeded.first())
        assertEquals("Textiles Nube", settings.companyName.first())

        val account = prefs.account()
        assertTrue(account.connected)
        assertEquals("Textiles Nube", account.tenantName)
        assertEquals(platform.refreshToken, prefs.refreshToken())
        assertNotNull(account.lastSyncAt)
    }

    @Test fun firstLinkOfAnExistingTabletSeedsAnEmptyCompany() = blocking {
        val catalog = CatalogService(db, images)
        catalog.savePlant(null, "Planta Local", 5000.0)
        db.syncDao().clearOutbox() // as if the data predates the sync migration
        platform.put("users", platform.userId, "2026-10-01T00:00:00.000Z", platform.userData)

        engine.signIn(platform.userEmail, "secreta")

        val pushed = platform.records.values.filter { it.entity == "plants" }
        assertEquals(listOf("Planta Local"), pushed.map { it.data!!["name"]!!.jsonPrimitive.content })
        assertTrue(db.syncDao().outbox().isEmpty())
        assertTrue(File(tmp, "backups").listFiles().isNullOrEmpty())
    }

    @Test fun pushesLocalWritesAndAdoptsNewerServerCopies() = blocking {
        engine.signIn(platform.userEmail, "secreta")
        val catalog = CatalogService(db, images)
        val mine = catalog.savePlant(null, "Mía", 1000.0)
        val theirs = catalog.savePlant(null, "Editada aquí", 1000.0)
        // Another device saved `theirs` later than this one.
        val later = db.syncDao().pending("plants", theirs.id)!!.changedAt + 60_000
        platform.put("plants", theirs.id, iso(later), plantData(theirs.id, "Editada allá", later))

        assertTrue(engine.syncNow(manual = true))

        assertEquals("Mía", platform.records["plants" to mine.id]!!.data!!["name"]!!.jsonPrimitive.content)
        assertEquals(SyncCodec.wireId(mine.id), platform.records["plants" to mine.id]!!.data!!["id"]!!.jsonPrimitive.content)
        assertEquals("Editada allá", db.dao().plant(theirs.id)!!.name)
        assertTrue(db.syncDao().outbox().isEmpty())
        assertTrue(messages.contains("Sincronizado" to false))

        // Deletes travel as tombstones.
        com.nevutech.trama.core.data.ProductionService(db, null).deletePlant(db.dao().plant(mine.id)!!)
        engine.syncNow()
        assertTrue(platform.records["plants" to mine.id]!!.deleted)
    }

    @Test fun expiredAccessTokenIsRefreshedAndRotated() = blocking {
        engine.signIn(platform.userEmail, "secreta")
        val firstRefresh = prefs.refreshToken()
        platform.accessToken = "rotated-by-server" // the 15-minute token expired

        assertTrue(engine.syncNow())

        assertTrue(platform.requests.contains("POST /auth/refresh"))
        assertNotEquals(firstRefresh, prefs.refreshToken())
        assertEquals(platform.refreshToken, prefs.refreshToken())

        // A revoked device must sign in again; local data stays.
        platform.refreshToken = "revoked-elsewhere-0000000"
        platform.accessToken = "rotated-again"
        assertFalse(engine.syncNow())
        assertFalse(prefs.account().connected)
        assertEquals("Tu sesión en la nube expiró. Vuelve a conectar tu licencia.", prefs.account().lastError)
    }

    @Test fun expiredLicenceMakesTheDeviceReadOnlyAndKeepsTheOutbox() = blocking {
        engine.signIn(platform.userEmail, "secreta")
        val catalog = CatalogService(db, images)
        catalog.savePlant(null, "Pendiente", 1000.0)
        platform.writable = false

        assertFalse(engine.syncNow())

        assertTrue(engine.status.first { it.readOnly }.readOnly)
        assertEquals(1, db.syncDao().outbox().size)
        val blocked = runCatching { catalog.savePlant(null, "Otra", 1000.0) }.exceptionOrNull()
        assertTrue(blocked?.message?.contains(READ_ONLY_MARKER) == true)
        assertTrue(messages.any { it.first.contains("solo lectura") && it.second })

        // Renewed: writes and pushes resume.
        platform.writable = true
        assertTrue(engine.syncNow())
        assertTrue(db.syncDao().outbox().isEmpty())
        catalog.savePlant(null, "Otra", 1000.0)
    }

    @Test fun forbiddenChangesAreReportedAndDropped() = blocking {
        engine.signIn(platform.userEmail, "secreta")
        platform.forbidEntities = setOf("plants")
        CatalogService(db, images).savePlant(null, "No permitida", 1000.0)

        assertTrue(engine.syncNow(manual = false))

        assertTrue(messages.contains("Tu puesto no permite este cambio." to true))
        assertTrue(db.syncDao().outbox().isEmpty())
    }

    @Test fun logoutRevokesTheDeviceAndKeepsLocalData() = blocking {
        engine.signIn(platform.userEmail, "secreta")
        CatalogService(db, images).savePlant(null, "Se queda", 1000.0)
        val issued = platform.refreshToken

        engine.signOutCloud()

        assertTrue(platform.requests.contains("POST /auth/logout"))
        assertNotEquals(issued, platform.refreshToken)
        assertFalse(prefs.account().connected)
        assertNull(prefs.refreshToken())
        assertEquals(1, db.dao().plants().first().size)
        assertFalse(engine.syncNow(manual = true))
        assertTrue(messages.contains("Conecta tu licencia para sincronizar." to true))
    }
}
