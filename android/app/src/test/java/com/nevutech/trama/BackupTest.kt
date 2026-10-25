package com.nevutech.trama

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.PasswordHasher
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.eraseAllData
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.ProductionTotals
import com.nevutech.trama.core.domain.Role
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
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
import java.time.Instant
import java.time.LocalDate
import java.util.Base64

/** Port of ios/TramaTests/BackupTests.swift, plus restoring a file written exactly like the iOS encoder. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BackupTest {
    private lateinit var context: Context
    private lateinit var images: ImageStore
    private val open = mutableListOf<TramaDatabase>()

    @Before fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        images = ImageStore(context)
    }

    @After fun tearDown() = open.forEach { it.close() }

    private fun newDb() = TramaDatabase.inMemory(context).also(open::add)

    private suspend fun seeded() = newDb().also { DemoSeeder.seed(it) }

    private suspend fun graph(db: TramaDatabase) = with(db.dao()) {
        Graph(plants().first(), clients().first(), suppliers().first(), contacts().first(), styles().first(),
            orders().first(), assignments().first(), reports().first(), projects().first(), users().first())
    }

    private fun counts(g: Graph) = listOf(
        g.plants.size, g.clients.size, g.suppliers.size, g.contacts.size, g.styles.size,
        g.orders.size, g.assignments.size, g.reports.size, g.projects.size, g.users.size,
    )

    private val png: ByteArray = Base64.getDecoder().decode(PNG)

    @Test fun roundTripPreservesCountsRelationshipsImagesAndMetrics() = runTest {
        val source = seeded()
        val dao = source.dao()
        val style = dao.styles().first().first()
        dao.upsert(style.copy(imageFile = images.save(png)))
        val project = dao.projects().first().first()
        val photo = images.save(png)
        dao.upsert(project.copy(photoFile = photo))
        val photoBytes = images.read(photo)!!

        val before = graph(source)
        val data = BackupService.export(source, images)

        val target = newDb()
        val summary = BackupService.restore(data, target, images)
        val after = graph(target)

        assertEquals(counts(before), counts(after))
        assertEquals(before.assignments.size, summary.counts.first { it.first == "Asignaciones" }.second)
        assertEquals(ProductionTotals.of(before.assignments.map(before::metrics)), ProductionTotals.of(after.assignments.map(after::metrics)))
        before.assignments.forEach { original ->
            val copy = after.assignment(original.id)!!
            assertEquals(original.orderId, copy.orderId)
            assertEquals(original.plantId, copy.plantId)
            assertEquals(before.reportsOf(original).map { it.id }.toSet(), after.reportsOf(copy).map { it.id }.toSet())
            assertEquals(before.cutStatus(original), after.cutStatus(copy))
            assertEquals(before.metrics(original), after.metrics(copy))
            assertEquals(original.createdAt, copy.createdAt)
        }
        before.orders.forEach { assertEquals(it, after.order(it.id)) }
        val bayer = after.clients.first { it.name == "Bayer California" }
        assertEquals(2, after.contactsOfClient(bayer.id).size)
        val manager = after.users.first { it.email == "planta@demo.local" }
        assertEquals("Planta Norte", after.plant(manager.plantId)?.name)

        // Images survive byte for byte (into new files).
        assertArrayEquals(images.read(before.style(style.id)!!.imageFile), images.read(after.style(style.id)!!.imageFile))
        assertArrayEquals(photoBytes, images.read(after.project(project.id)!!.photoFile))

        // Passwords still work.
        val admin = after.users.first { it.email == "admin@demo.local" }
        assertTrue(PasswordHasher.verify(DemoSeeder.DEMO_PASSWORD, admin.passwordHash, admin.passwordSalt))
    }

    @Test fun restoreReplacesExistingData() = runTest {
        val data = BackupService.export(seeded(), images)
        val target = seeded()
        BackupService.restore(data, target, images)
        assertEquals(3, target.dao().plants().first().size)
        assertEquals(4, target.dao().users().first().size)
    }

    @Test fun eraseAllRemovesEveryEntity() = runTest {
        val db = seeded()
        eraseAllData(db, images)
        assertTrue(counts(graph(db)).all { it == 0 })
    }

    @Test fun fileHeaderKeysAndFilename() = runTest {
        val data = BackupService.export(seeded(), images, now = Instant.parse("2026-10-24T18:03:12.345Z"), version = "1.0.0 (1)")
        val text = data.toString(Charsets.UTF_8)
        val root = Json.parseToJsonElement(text).jsonObject
        assertEquals(1, root["formatVersion"]!!.jsonPrimitive.int)
        assertEquals("2026-10-24T18:03:12.345Z", root["exportedAt"]!!.jsonPrimitive.content)
        assertEquals("1.0.0 (1)", root["appVersion"]!!.jsonPrimitive.content)
        // Sorted keys like iOS JSONEncoder(.sortedKeys).
        assertEquals(root.keys.sorted(), root.keys.toList())
        val assignment = root["assignments"]!!.jsonArray.first().jsonObject
        assertEquals(assignment.keys.sorted(), assignment.keys.toList())
        assertTrue(assignment.keys.containsAll(listOf("cuttingStatusRaw", "orderID", "plantID", "scheduledDate", "remoteID")))
        val id = assignment["id"]!!.jsonPrimitive.content
        assertEquals(id.uppercase(), id)
        assertTrue(Regex("""\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z""").matches(assignment["createdAt"]!!.jsonPrimitive.content))
        // nil values are omitted, never written as null.
        assertFalse(text.contains("null"))
        assertEquals(3, BackupService.inspect(data).counts.first { it.first == "Plantas" }.second)
        assertEquals("Trama-respaldo-2026-03-09.json", BackupService.filename(LocalDate.of(2026, 3, 9)))
    }

    @Test fun rejectsNewerVersionAndGarbageWithoutTouchingData() = runTest {
        val target = seeded()
        val newer = runCatching { BackupService.restore("""{"formatVersion": 99, "plants": []}""".toByteArray(), target, images) }.exceptionOrNull()
        assertEquals(BackupService.BackupError.UnsupportedVersion(99), newer)
        listOf("nope", "{}", """{"formatVersion": 0}""", """{"formatVersion": 1, "plants": [{"id": "not-a-uuid"}]}""",
            """{"formatVersion": 1, "orders": [{"clientDate": "ayer"}]}""").forEach { bad ->
            val error = runCatching { BackupService.restore(bad.toByteArray(), target, images) }.exceptionOrNull()
            assertEquals(bad, BackupService.BackupError.InvalidFile, error)
        }
        assertEquals(3, target.dao().plants().first().size)
        assertEquals(7, target.dao().orders().first().size)
    }

    @Test fun toleratesMissingOptionalKeys() = runTest {
        val plantId = "5B1E3C7A-2D4F-4A8B-9C6D-1E2F3A4B5C6D"
        val json = """
            {"formatVersion": 1,
             "plants": [{"id": "$plantId", "name": "Mínima"}],
             "orders": [{"id": "0D1C2B3A-4F5E-4D6C-8B7A-9F8E7D6C5B4A", "quantity": 10}],
             "assignments": [{"quantity": 10, "plantID": "$plantId", "orderID": "0D1C2B3A-4F5E-4D6C-8B7A-9F8E7D6C5B4A", "futureField": true}],
             "somethingNew": {"x": 1}}
        """.trimIndent()
        val target = newDb()
        BackupService.restore(json.toByteArray(), target, images)
        val g = graph(target)
        val plant = g.plants.single()
        assertEquals(0.0, plant.maxCapacity, 0.0)
        assertEquals(plantId.lowercase(), plant.id)
        val assignment = g.assignmentsOf(plant).single()
        assertEquals(CutStatus.Waiting, g.cutStatus(assignment))
        assertTrue(assignment.id.isNotEmpty())
    }

    /** A file written exactly as iOS JSONEncoder produces it (sorted keys, uppercase UUIDs, ms dates, base64). */
    @Test fun restoresIosFixture() = runTest {
        val target = seeded() // pre-existing data must be replaced
        val summary = BackupService.restore(IOS_FIXTURE.toByteArray(), target, images)
        assertEquals(Instant.parse("2026-10-24T18:03:12.345Z"), summary.exportedAt)
        assertEquals("1.0 (12)", summary.appVersion)
        val g = graph(target)
        assertEquals(listOf(1, 1, 1, 2, 1, 1, 1, 3, 1, 1), counts(g))

        val plant = g.plants.single()
        assertEquals("a1b2c3d4-0000-4000-8000-000000000001", plant.id)
        assertEquals(1_800_000.0, plant.maxCapacity, 0.0)
        assertEquals(7L, plant.remoteId)

        val order = g.orders.single()
        assertEquals("Bayer California", g.clientName(order))
        assertEquals("Falda plisada SK-210", g.styleName(order))
        assertEquals(Instant.parse("2026-10-28T06:00:00Z").toEpochMilli(), order.clientDate)
        assertEquals("", order.list)

        val client = g.clients.single()
        assertEquals(listOf("Laura Méndez", "Óscar Ruiz"), g.contactsOfClient(client.id).map { it.name })
        assertEquals(0, g.contactsOfSupplier(g.suppliers.single().id).size)

        val assignment = g.assignments.single()
        assertEquals(CutStatus.Ready, g.cutStatus(assignment))
        val m = g.metrics(assignment)
        assertEquals(3_960, m.realCut)
        assertEquals(3_400, m.produced)
        assertEquals(1_200, m.shipped)
        assertEquals(2_760, m.toShip)
        assertEquals(272_000.0, m.revenue, 0.0)

        assertArrayEquals(png, images.read(g.styles.single().imageFile))
        assertNull(g.projects.single().photoFile)
        assertEquals(client.id, g.projects.single().clientId)

        val user = g.users.single()
        assertEquals("admin@demo.local", user.email)
        assertEquals(Role.Admin, Role.fromRaw(user.role))
        assertEquals(plant.id, user.plantId)
        assertTrue(PasswordHasher.verify("trama123", user.passwordHash, user.passwordSalt))
        assertNotNull(images.read(user.avatarFile))

        // And it re-exports with the same ids iOS wrote.
        val again = BackupService.export(target, images).toString(Charsets.UTF_8)
        assertTrue(again.contains("\"A1B2C3D4-0000-4000-8000-000000000001\""))
        assertTrue(again.contains("\"clientDate\":\"2026-10-28T06:00:00.000Z\""))
    }

    private companion object {
        const val PNG = "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGMQicmDIwbiOABjYw3hh/M9ogAAAABJRU5ErkJggg=="

        // PBKDF2-SHA256("trama123", salt 00..0f, 120k, 32 bytes) computed independently (Python hashlib).
        const val HASH = "zcwRAuc66SSMfJ2S4LMBXmx9ZZUytXkJe52oTpWoI3A="

        // iOS writes compact JSON; whitespace here is only for readability and is valid JSON either way.
        val IOS_FIXTURE = """
        {
          "appVersion" : "1.0 (12)",
          "assignments" : [
            {"createdAt":"2026-10-06T15:20:00.120Z","cuttingStatusRaw":"listo_para_confeccionar","id":"A1B2C3D4-0000-4000-8000-000000000301","orderID":"A1B2C3D4-0000-4000-8000-000000000201","plantID":"A1B2C3D4-0000-4000-8000-000000000001","quantity":4000,"remoteID":0,"scheduledDate":"2026-10-06T06:00:00.000Z","unitPrice":68,"updatedAt":"2026-10-06T15:20:00.120Z"}
          ],
          "clients" : [
            {"address":"Av. Insurgentes Sur 1458, CDMX","createdAt":"2026-10-01T10:00:00.000Z","id":"A1B2C3D4-0000-4000-8000-000000000101","name":"Bayer California","remoteID":0,"updatedAt":"2026-10-01T10:00:00.000Z"}
          ],
          "contacts" : [
            {"clientID":"A1B2C3D4-0000-4000-8000-000000000101","email":"oscar.ruiz@bayerca.com","id":"A1B2C3D4-0000-4000-8000-000000000112","name":"Óscar Ruiz","phone":"55 2345 9900","role":"Calidad","sortIndex":1},
            {"clientID":"A1B2C3D4-0000-4000-8000-000000000101","email":"laura.mendez@bayerca.com","id":"A1B2C3D4-0000-4000-8000-000000000111","name":"Laura Méndez","phone":"55 2345 9988","role":"Compras","sortIndex":0}
          ],
          "exportedAt" : "2026-10-24T18:03:12.345Z",
          "formatVersion" : 1,
          "orders" : [
            {"clientDate":"2026-10-28T06:00:00.000Z","clientID":"A1B2C3D4-0000-4000-8000-000000000101","code":"C-1042","createdAt":"2026-10-04T06:00:00.000Z","editedBy":"Mariana Treviño","garment":"Falda","id":"A1B2C3D4-0000-4000-8000-000000000201","internalDate":"2026-10-04T06:00:00.000Z","quantity":4000,"remoteID":0,"styleID":"A1B2C3D4-0000-4000-8000-000000000401","unitPrice":68,"updatedAt":"2026-10-04T06:00:00.000Z"}
          ],
          "plants" : [
            {"createdAt":"2026-10-01T10:00:00.000Z","id":"A1B2C3D4-0000-4000-8000-000000000001","maxCapacity":1800000,"name":"Planta Norte","remoteID":7,"updatedAt":"2026-10-02T11:30:45.678Z"}
          ],
          "projects" : [
            {"clientID":"A1B2C3D4-0000-4000-8000-000000000101","clientName":"Bayer California","createdAt":"2026-10-01T10:00:00.000Z","deliveryDate":"2026-12-24T06:00:00.000Z","fabric":"Popelina 100% algodón","id":"A1B2C3D4-0000-4000-8000-000000000501","minutes":11.5,"notes":"Entregas parciales cada 15 días.","price":72,"quantity":8000,"remoteID":0,"statusRaw":"aceptado","updatedAt":"2026-10-01T10:00:00.000Z"}
          ],
          "reports" : [
            {"absences":0,"assignmentID":"A1B2C3D4-0000-4000-8000-000000000301","authorName":"Carmen Ruiz","createdAt":"2026-10-07T09:00:00.100Z","cutStatusRaw":"listo_para_confeccionar","id":"A1B2C3D4-0000-4000-8000-000000000601","ironing":0,"kindRaw":"corte","operators":0,"packing":0,"produced":0,"realQuantity":3960,"remoteID":0,"shippedQuantity":0,"updatedAt":"2026-10-07T09:00:00.100Z","warehouse":0},
            {"absences":3,"assignmentID":"A1B2C3D4-0000-4000-8000-000000000301","authorName":"Jorge Salinas","createdAt":"2026-10-07T09:00:00.200Z","id":"A1B2C3D4-0000-4000-8000-000000000602","ironing":600,"kindRaw":"planta","operators":42,"packing":900,"produced":3400,"realQuantity":0,"remoteID":0,"shippedQuantity":0,"updatedAt":"2026-10-07T09:00:00.200Z","warehouse":1400},
            {"absences":0,"assignmentID":"A1B2C3D4-0000-4000-8000-000000000301","authorName":"Ana Villarreal","createdAt":"2026-10-07T09:00:00.300Z","id":"A1B2C3D4-0000-4000-8000-000000000603","ironing":0,"kindRaw":"envio","operators":0,"packing":0,"produced":0,"realQuantity":0,"remoteID":0,"shipmentNumber":"E-501","shippedQuantity":1200,"updatedAt":"2026-10-07T09:00:00.300Z","warehouse":0}
          ],
          "styles" : [
            {"createdAt":"2026-10-01T10:00:00.000Z","id":"A1B2C3D4-0000-4000-8000-000000000401","imageData":"$PNG","name":"Falda plisada SK-210","remoteID":0,"updatedAt":"2026-10-01T10:00:00.000Z"}
          ],
          "suppliers" : [
            {"address":"León, Gto.","createdAt":"2026-10-01T10:00:00Z","id":"A1B2C3D4-0000-4000-8000-000000000701","name":"Hilados del Bajío","remoteID":0,"updatedAt":"2026-10-01T10:00:00Z"}
          ],
          "users" : [
            {"avatarData":"$PNG","createdAt":"2026-10-01T10:00:00.000Z","email":"admin@demo.local","firstName":"Mariana","id":"A1B2C3D4-0000-4000-8000-000000000801","isActive":true,"lastName":"Treviño","passwordHash":"$HASH","passwordSalt":"AAECAwQFBgcICQoLDA0ODw==","phone":"","plantID":"A1B2C3D4-0000-4000-8000-000000000001","remoteID":0,"roleRaw":"Administrador","updatedAt":"2026-10-01T10:00:00.000Z"}
          ]
        }
        """.trimIndent()
    }
}
