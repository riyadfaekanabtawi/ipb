package com.nevutech.trama

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.CatalogService
import com.nevutech.trama.core.data.ContactDraft
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.ImageEdit
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.ProductionService
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.eraseAllData
import com.nevutech.trama.core.data.sync.MIGRATION_1_2
import com.nevutech.trama.core.data.sync.READ_ONLY_MARKER
import com.nevutech.trama.core.data.sync.ServerChange
import com.nevutech.trama.core.data.sync.SyncCodec
import com.nevutech.trama.core.data.sync.SyncStore
import com.nevutech.trama.core.domain.CutStatus
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate

/** Sync on the device side: payload format, outbox triggers, applying pulled changes, migration. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SyncLocalTest {
    private lateinit var context: Context
    private lateinit var db: TramaDatabase
    private lateinit var images: ImageStore
    private lateinit var store: SyncStore

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        db = TramaDatabase.inMemory(context)
        images = ImageStore(context).also { it.clear() }
        store = SyncStore(db, images)
    }

    @After fun tearDown() = db.close()

    private val sync get() = db.syncDao()
    private fun iso(ms: Long) = BackupService.formatDate(ms)

    // Payload format

    @Test fun payloadsAreExactlyTheBackupElements() = runTest {
        DemoSeeder.seed(db, LocalDate.of(2026, 10, 1))
        val catalog = CatalogService(db, images)
        val style = db.dao().styles().first().first()
        catalog.saveStyle(style, style.name, ImageEdit.Replace(byteArrayOf(1, 2, 3, 4)))
        val backup = Json.parseToJsonElement(BackupService.export(db, images).toString(Charsets.UTF_8)).jsonObject

        fun element(key: String, id: String) = backup[key]!!.jsonArray.map { it.jsonObject }.first { it["id"]!!.jsonPrimitive.content == id }
        for (row in store.pending()) {
            val change = store.change(row)
            assertEquals(SyncCodec.wireId(row.id), change.id)
            assertEquals(change.id.uppercase(), change.id)
            // Same keys and values as the backup file, so iOS, Android and the server agree on one format.
            assertEquals("${row.entity}/${row.id}", element(row.entity, change.id), change.data)
        }
        val styleChange = store.change(store.pending().first { it.entity == "styles" && it.id == style.id })
        val stored = images.read(db.dao().styles().first().first { it.id == style.id }.imageFile)!!
        assertEquals(java.util.Base64.getEncoder().encodeToString(stored), styleChange.data!!["imageData"]!!.jsonPrimitive.content)
        assertTrue(Regex("""\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z""").matches(styleChange.updatedAt))
    }

    @Test fun payloadRoundTripsThroughApply() = runTest {
        DemoSeeder.seed(db, LocalDate.of(2026, 10, 1))
        val changes = store.pending().map { row ->
            store.change(row).let { ServerChange(it.entity, it.id.lowercase(), it.updatedAt, false, it.data, 1) }
        }
        val before = BackupService.export(db, images, java.time.Instant.EPOCH, "test")

        val other = TramaDatabase.inMemory(context)
        try {
            val result = SyncStore(other, images).apply(changes.shuffled(), cursor = 42)
            assertEquals(changes.size, result.applied)
            assertEquals(42, SyncStore(other, images).cursor())
            assertTrue("applying pulled changes must not enqueue", other.syncDao().outbox().isEmpty())
            assertEquals(normalized(before), normalized(BackupService.export(other, images, java.time.Instant.EPOCH, "test")))
        } finally {
            other.close()
        }
    }

    /** Backup JSON with every entity list sorted by id (row order among equal sort keys is insertion order). */
    private fun normalized(bytes: ByteArray): JsonObject {
        val root = Json.parseToJsonElement(bytes.toString(Charsets.UTF_8)).jsonObject
        return JsonObject(root.mapValues { (_, value) ->
            if (value is kotlinx.serialization.json.JsonArray) kotlinx.serialization.json.JsonArray(value.sortedBy { it.jsonObject["id"]!!.jsonPrimitive.content }) else value
        })
    }

    // Outbox

    @Test fun serviceWritesAreQueuedAndCoalesced() = runTest {
        val catalog = CatalogService(db, images)
        val plant = catalog.savePlant(null, "Norte", 1_000_000.0)
        catalog.savePlant(plant, "Norte 2", 1_000_000.0)
        val client = catalog.saveClient(null, "Cliente", "", listOf(ContactDraft(name = "Ana"), ContactDraft(name = "Luis")))

        val rows = sync.outbox().associateBy { it.entity to it.id }
        assertEquals(4, rows.size)
        assertFalse(rows["plants" to plant.id]!!.deleted)
        assertTrue(rows["plants" to plant.id]!!.rev >= 2)
        assertNotNull(rows["clients" to client.id])
        assertEquals(2, rows.keys.count { it.first == "contacts" })

        // Editing the contacts again drops one: the removed contact becomes a tombstone.
        val kept = db.dao().contacts().first().first { it.name == "Ana" }
        catalog.saveClient(db.dao().clients().first().first(), "Cliente", "", listOf(ContactDraft.of(kept)))
        val contacts = sync.outbox().filter { it.entity == "contacts" }
        assertEquals(listOf(false, true), contacts.sortedBy { it.deleted }.map { it.deleted })
    }

    @Test fun deletesAndCascadesQueueTombstones() = runTest {
        DemoSeeder.seed(db, LocalDate.of(2026, 10, 1))
        sync.clearOutbox()
        val production = ProductionService(db, "QA")
        val order = db.dao().orders().first().first { o -> db.dao().assignmentsOfOrder(o.id).isNotEmpty() && db.dao().assignmentsOfOrder(o.id).all { db.dao().reportsOf(it.id).isEmpty() } }
        val assignments = db.dao().assignmentsOfOrder(order.id).map { it.id }.toSet()
        production.deleteOrder(order)

        val rows = sync.outbox()
        assertTrue(rows.single { it.entity == "orders" }.deleted)
        assertEquals(assignments, rows.filter { it.entity == "assignments" && it.deleted }.map { it.id }.toSet())
        // Push order: tombstones go children-first.
        val pending = store.pending()
        assertTrue(pending.indexOfFirst { it.entity == "assignments" } < pending.indexOfFirst { it.entity == "orders" })
        assertNull(store.change(rows.single { it.entity == "orders" }).data)
    }

    @Test fun eraseAndAppliedChangesAreNotQueued() = runTest {
        DemoSeeder.seed(db, LocalDate.of(2026, 10, 1))
        assertTrue(sync.outbox().isNotEmpty())
        eraseAllData(db, images)
        assertTrue(sync.outbox().isEmpty())
        assertFalse(store.hasLocalData())
        assertFalse(sync.state()!!.applying)
    }

    @Test fun readOnlyLicenceBlocksLocalWritesButNotSync() = runTest {
        val catalog = CatalogService(db, images)
        val plant = catalog.savePlant(null, "Norte", 1_000_000.0)
        store.setReadOnly(true)
        val error = runCatching { catalog.savePlant(null, "Sur", 10.0) }.exceptionOrNull()
        assertTrue("got $error", error?.message?.contains(READ_ONLY_MARKER) == true)
        assertTrue(com.nevutech.trama.designsystem.ToastCenter.userMessage(error!!).contains("solo lectura"))

        // Pulled changes still apply while read-only.
        val data = SyncCodec.encode(plant.copy(name = "Norte remoto", updatedAt = plant.updatedAt + 1000))
        store.apply(listOf(ServerChange("plants", plant.id, iso(plant.updatedAt + 1000), false, data, 5)), force = true)
        assertEquals("Norte remoto", db.dao().plant(plant.id)!!.name)
        store.setReadOnly(false)
        catalog.savePlant(null, "Sur", 10.0)
    }

    // Apply

    @Test fun applyUpsertsDeletesAndOrdersParentsFirst() = runTest {
        val t = 1_760_000_000_000
        val plant = "0f8b5c34-38a5-4d3c-b2a8-0e1d5f6a7b01"
        val client = "1f8b5c34-38a5-4d3c-b2a8-0e1d5f6a7b02"
        val order = "2f8b5c34-38a5-4d3c-b2a8-0e1d5f6a7b03"
        val assignment = "3f8b5c34-38a5-4d3c-b2a8-0e1d5f6a7b04"
        fun obj(vararg pairs: Pair<String, Any>) = JsonObject(pairs.associate { (k, v) -> k to if (v is Number) JsonPrimitive(v) else JsonPrimitive(v.toString()) })
        // Children first, uppercase ids, as another client might send them.
        val changes = listOf(
            ServerChange("assignments", assignment.uppercase(), iso(t), false,
                obj("id" to assignment.uppercase(), "orderID" to order.uppercase(), "plantID" to plant.uppercase(), "quantity" to 10, "unitPrice" to 5.0, "scheduledDate" to iso(t), "cuttingStatusRaw" to CutStatus.OnTable.raw), 4),
            ServerChange("orders", order, iso(t), false, obj("id" to order, "code" to "C-1", "quantity" to 100, "unitPrice" to 5.0, "clientID" to client.uppercase()), 3),
            ServerChange("clients", client, iso(t), false, obj("id" to client, "name" to "Cliente"), 2),
            ServerChange("plants", plant, iso(t), false, obj("id" to plant, "name" to "Norte", "maxCapacity" to 1000.0), 1),
        )
        val result = store.apply(changes, cursor = 4)
        assertEquals(4, result.applied)
        assertEquals(client, db.dao().order(order)!!.clientId)
        assertEquals(plant, db.dao().assignment(assignment)!!.plantId)
        assertEquals(CutStatus.OnTable.raw, db.dao().assignment(assignment)!!.cuttingStatus)

        // Tombstones delete by id; a newer version of the same row in one batch wins.
        store.apply(
            listOf(
                ServerChange("assignments", assignment, iso(t + 1), true, null, 6),
                ServerChange("orders", order, iso(t + 1), false, obj("id" to order, "code" to "C-1b", "quantity" to 100, "unitPrice" to 5.0), 5),
                ServerChange("orders", order, iso(t + 2), false, obj("id" to order, "code" to "C-1c", "quantity" to 100, "unitPrice" to 5.0), 7),
            ),
            cursor = 7,
        )
        assertNull(db.dao().assignment(assignment))
        assertEquals("C-1c", db.dao().order(order)!!.code)
        assertNull("the newest copy (without a client) replaced the row", db.dao().order(order)!!.clientId)
        assertTrue(sync.outbox().isEmpty())

        // A plant still referenced locally can't be deleted (RESTRICT): skipped, not fatal.
        val local = ProductionService(db, null).assign(order, plant, 5, LocalDate.of(2026, 10, 5))
        val skipped = store.apply(listOf(ServerChange("plants", plant, iso(t + 3), true, null, 8)))
        assertEquals(1, skipped.skipped)
        assertNotNull(db.dao().plant(plant))
        assertNotNull(db.dao().assignment(local.id))
    }

    @Test fun lastWriterWinsAgainstPendingLocalEdits() = runTest {
        val catalog = CatalogService(db, images)
        val plant = catalog.savePlant(null, "Local", 1_000.0)
        val pending = sync.pending("plants", plant.id)!!

        // Older server copy: the local edit wins and stays queued.
        val older = SyncCodec.encode(plant.copy(name = "Viejo"))
        val r1 = store.apply(listOf(ServerChange("plants", plant.id, iso(pending.changedAt - 60_000), false, older, 3)))
        assertEquals(1, r1.skipped)
        assertEquals("Local", db.dao().plant(plant.id)!!.name)
        assertNotNull(sync.pending("plants", plant.id))

        // Newer server copy: it replaces the row and the stale local edit is dropped.
        val newer = SyncCodec.encode(plant.copy(name = "Remoto"))
        store.apply(listOf(ServerChange("plants", plant.id, iso(pending.changedAt + 60_000), false, newer, 4)))
        assertEquals("Remoto", db.dao().plant(plant.id)!!.name)
        assertNull(sync.pending("plants", plant.id))
    }

    @Test fun pulledUsersKeepOfflineLoginAndReplaceSameEmail() = runTest {
        DemoSeeder.seed(db, LocalDate.of(2026, 10, 1))
        val local = db.dao().userByEmail("admin@demo.local")!!
        val serverId = "9f8b5c34-38a5-4d3c-b2a8-0e1d5f6a7b09"
        val data = SyncCodec.encode(local.copy(id = serverId, firstName = "Nube", avatarFile = null), byteArrayOf(9, 9))
        val user = store.adoptUser(data)!!
        assertEquals(serverId, user.id)
        assertNull(db.dao().user(local.id))
        assertEquals("Nube", db.dao().userByEmail("admin@demo.local")!!.firstName)
        assertArrayEquals(byteArrayOf(9, 9), images.read(user.avatarFile))

        // The synced hash works with the app's PBKDF2 sign-in, with no network.
        val session = com.nevutech.trama.core.data.Session(db.dao(), com.nevutech.trama.core.data.SettingsStore(context))
        session.signIn("admin@demo.local", DemoSeeder.DEMO_PASSWORD)
        assertEquals(serverId, session.user.value!!.id)
    }

    // Migration

    /**
     * Builds a real version-1 file from the exported schema (schemas/…/1.json), then opens it with
     * the current Room setup: Room runs MIGRATION_1_2 and validates the result against v2.
     */
    @Test fun migratesVersion1WithoutLosingData() = runTest {
        val name = "migration-test.db"
        context.deleteDatabase(name)
        val schema = Json.parseToJsonElement(java.io.File("schemas/com.nevutech.trama.core.data.TramaDatabase/1.json").readText())
            .jsonObject["database"]!!.jsonObject
        android.database.sqlite.SQLiteDatabase.openOrCreateDatabase(context.getDatabasePath(name).apply { parentFile?.mkdirs() }, null).use { v1 ->
            for (entity in schema["entities"]!!.jsonArray.map { it.jsonObject }) {
                val table = entity["tableName"]!!.jsonPrimitive.content
                v1.execSQL(entity["createSql"]!!.jsonPrimitive.content.replace("\${TABLE_NAME}", table))
                entity["indices"]?.jsonArray?.forEach { v1.execSQL(it.jsonObject["createSql"]!!.jsonPrimitive.content.replace("\${TABLE_NAME}", table)) }
            }
            schema["setupQueries"]!!.jsonArray.forEach { v1.execSQL(it.jsonPrimitive.content) }
            v1.execSQL("INSERT INTO plant (id, name, maxCapacity, remoteId, createdAt, updatedAt) VALUES ('p1', 'Norte', 100.0, 0, 1, 1)")
            v1.version = 1
        }

        val migrated = Room.databaseBuilder(context, TramaDatabase::class.java, name)
            .addMigrations(MIGRATION_1_2).addCallback(TramaDatabase.syncCallback).build()
        try {
            assertEquals("Norte", migrated.dao().plant("p1")!!.name)
            assertTrue("existing rows are not queued by the migration", migrated.syncDao().outbox().isEmpty())
            assertEquals(0L, migrated.syncDao().state()!!.cursor)
            CatalogService(migrated, images).savePlant(migrated.dao().plant("p1"), "Norte 2", 100.0)
            assertEquals(listOf("p1"), migrated.syncDao().outbox().map { it.id })
        } finally {
            migrated.close()
            context.deleteDatabase(name)
        }
    }
}
