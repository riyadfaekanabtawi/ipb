package com.nevutech.trama

import androidx.test.core.app.ApplicationProvider
import com.nevutech.trama.core.data.AuthError
import com.nevutech.trama.core.data.AuthException
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.PasswordHasher
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.data.ProductionService
import com.nevutech.trama.core.data.ServiceException
import com.nevutech.trama.core.data.Session
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.domain.AssignmentError
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.OrderAssignmentState
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.Role
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate
import java.time.YearMonth

/** Port of ios/TramaTests/PersistenceTests.swift + ProductionFlowTests.swift against Room. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DataTest {
    private lateinit var db: TramaDatabase
    private lateinit var service: ProductionService

    @Before fun setUp() {
        db = TramaDatabase.inMemory(ApplicationProvider.getApplicationContext())
        service = ProductionService(db, "Test")
    }

    @After fun tearDown() = db.close()

    private suspend fun graph() = with(db.dao()) {
        Graph(plants().first(), clients().first(), suppliers().first(), contacts().first(), styles().first(),
            orders().first(), assignments().first(), reports().first(), projects().first(), users().first())
    }

    private suspend fun plant(capacity: Double = 100_000.0) = PlantEntity(name = "Planta Test", maxCapacity = capacity).also { db.dao().upsert(it) }
    private suspend fun order(qty: Long = 1_000, price: Double = 10.0) =
        service.saveOrder(null, "C-1", "L-1", "Falda", qty, price, null, null, LocalDate.now(), LocalDate.now(), null)

    @Test fun assignReducesRemainingAndUpdatesState() = runTest {
        val p = plant(); val o = order()
        assertEquals(OrderAssignmentState.Unassigned, graph().let { it.state(it.order(o.id)!!) })
        service.assign(o.id, p.id, 400, LocalDate.now())
        graph().let { g -> assertEquals(600L, g.remaining(g.order(o.id)!!)); assertEquals(OrderAssignmentState.Partial, g.state(g.order(o.id)!!)) }
        service.assign(o.id, p.id, 600, LocalDate.now())
        graph().let { g -> assertEquals(OrderAssignmentState.Assigned, g.state(g.order(o.id)!!)) }
        val failure = runCatching { service.assign(o.id, p.id, 1, LocalDate.now()) }.exceptionOrNull()
        assertTrue(failure is AssignmentError.ExceedsRemaining)
    }

    @Test fun assignRespectsMonthlyCapacity() = runTest {
        val p = plant(5_000.0); val o = order(1_000, 10.0)
        assertTrue(runCatching { service.assign(o.id, p.id, 600, LocalDate.now()) }.exceptionOrNull() is AssignmentError.ExceedsCapacity)
        service.assign(o.id, p.id, 500, LocalDate.now())
        graph().let { g -> assertEquals(0.0, g.ledger(g.plant(p.id)!!).available(YearMonth.now()), 0.0) }
    }

    @Test fun onlyOneCutReportPerAssignmentAndKanbanReusesIt() = runTest {
        val a = service.assign(order().id, plant().id, 100, LocalDate.now())
        service.saveCutReport(CutStatus.OnTable, 97, a.id)
        assertTrue(runCatching { service.saveCutReport(CutStatus.Ready, 99, a.id) }.exceptionOrNull() is ServiceException)
        service.move(a.id, CutStatus.Ready)
        val g = graph(); val live = g.assignment(a.id)!!
        assertEquals(CutStatus.Ready, g.cutStatus(live))
        assertEquals(97L, g.cutReport(live)!!.realQuantity)
        assertEquals(1, g.reportsOf(live).count { it.kind == ReportKind.Cut.raw })
    }

    @Test fun metricsFlowThroughReports() = runTest {
        val a = service.assign(order().id, plant().id, 300, LocalDate.now())
        service.savePlantReport(ProductionService.PlantReportInput(operators = 5, produced = 120), a.id)
        service.saveShipmentReport("E-1", 100, a.id)
        service.saveShipmentReport("E-2", 50, a.id)
        val m = graph().let { it.metrics(it.assignment(a.id)!!) }
        assertEquals(120, m.produced); assertEquals(150, m.shipped); assertEquals(150, m.toShip)
    }

    @Test fun guardedDeletes() = runTest {
        val p = plant(); val o = order()
        val a = service.assign(o.id, p.id, 10, LocalDate.now())
        assertTrue(runCatching { service.deletePlant(p) }.exceptionOrNull() is ServiceException)
        service.saveShipmentReport("1", 1, a.id)
        assertTrue(runCatching { service.deleteOrder(o) }.exceptionOrNull() is ServiceException)
    }

    @Test fun authHashesAndVerifies() = runTest {
        val dao = db.dao()
        val user = Session.createUser(dao, "Ana", "P", "Ana@DEMO.local", "", "secreto1", Role.ShippingManager, null)
        assertEquals("ana@demo.local", user.email)
        assertNotEquals("secreto1", user.passwordHash)
        assertTrue(PasswordHasher.verify("secreto1", user.passwordHash, user.passwordSalt))
        val err = runCatching { Session.createUser(dao, "A", "", "ana@demo.local", "", "123456", Role.Admin, null) }.exceptionOrNull()
        assertEquals(AuthError.EmailTaken, (err as AuthException).error)
        val weak = runCatching { Session.createUser(dao, "B", "", "b@demo.local", "", "123", Role.Admin, null) }.exceptionOrNull()
        assertEquals(AuthError.WeakPassword, (weak as AuthException).error)
    }

    @Test fun pbkdf2MatchesIosForKnownVector() {
        // Same salt/password → same base64 as CommonCrypto on iOS (PBKDF2-HMAC-SHA256, 120k, 32 bytes).
        val salt = "AAECAwQFBgcICQoLDA0ODw=="
        assertEquals("zcwRAuc66SSMfJ2S4LMBXmx9ZZUytXkJe52oTpWoI3A=", PasswordHasher.hash("trama123", salt))
        assertNotEquals(PasswordHasher.hash("trama123", salt), PasswordHasher.hash("trama124", salt))
    }

    @Test fun demoSeedIsConsistentAndPlantManagersAreScoped() = runTest {
        DemoSeeder.seed(db)
        val g = graph()
        assertEquals(3, g.plants.size)
        assertEquals(4, g.users.size)
        assertTrue(g.assignments.any { g.isUrgent(it, 7) })
        g.plants.forEach { assertTrue(g.ledger(it).utilization(YearMonth.now()) <= 1.0) }
        val manager = g.users.first { it.email == "planta@demo.local" }
        val visible = g.visibleAssignments(manager)
        assertTrue(visible.isNotEmpty() && visible.size < g.assignments.size)
        assertTrue(visible.all { it.plantId == manager.plantId })
    }
}
