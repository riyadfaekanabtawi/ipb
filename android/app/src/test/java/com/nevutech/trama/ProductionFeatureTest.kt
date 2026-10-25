package com.nevutech.trama

import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.ClientEntity
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.Graph
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.data.ReportEntity
import com.nevutech.trama.core.data.toEpochMillis
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.feature.production.CalendarEvent
import com.nevutech.trama.feature.production.CalendarMath
import com.nevutech.trama.feature.production.OrderFilter
import com.nevutech.trama.feature.production.ProductionCsv
import com.nevutech.trama.feature.production.ProductionFilter
import com.nevutech.trama.feature.production.ProductionRow
import com.nevutech.trama.feature.production.ProductionSort
import com.nevutech.trama.feature.production.UrgentGroups
import com.nevutech.trama.feature.production.bestFitPlant
import com.nevutech.trama.feature.production.productionRows
import com.nevutech.trama.feature.production.sortedOrders
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth

/** Pure logic behind the production screens (JVM only, no Android). */
class ProductionFeatureTest {
    private val today = LocalDate.of(2026, 10, 15)

    private val north = PlantEntity(id = "p1", name = "Norte", maxCapacity = 100_000.0)
    private val south = PlantEntity(id = "p2", name = "Sur", maxCapacity = 50_000.0)
    private val acme = ClientEntity(id = "c1", name = "Acme, S.A.")
    private val beta = ClientEntity(id = "c2", name = "Beta")

    private val orderA = CutOrderEntity(id = "o1", code = "A-1", list = "L1", garment = "Falda", quantity = 100, unitPrice = 10.0, clientId = "c1", clientDate = today.plusDays(3).toEpochMillis(), internalDate = today.toEpochMillis())
    private val orderB = CutOrderEntity(id = "o2", code = "B-2", quantity = 50, unitPrice = 20.0, clientId = "c2", clientDate = today.minusDays(2).toEpochMillis())
    private val orderC = CutOrderEntity(id = "o3", code = "C-3", quantity = 10, unitPrice = 5.0, clientId = "c2")

    private val a1 = AssignmentEntity(id = "a1", orderId = "o1", plantId = "p1", quantity = 100, unitPrice = 10.0, scheduledDate = today.toEpochMillis(), cuttingStatus = CutStatus.OnTable.raw)
    private val a2 = AssignmentEntity(id = "a2", orderId = "o2", plantId = "p2", quantity = 20, unitPrice = 20.0, scheduledDate = today.plusDays(1).toEpochMillis())
    private val reports = listOf(
        ReportEntity(assignmentId = "a1", kind = ReportKind.Cut.raw, cutStatus = CutStatus.OnTable.raw, realQuantity = 90, createdAt = 1),
        ReportEntity(assignmentId = "a1", kind = ReportKind.Plant.raw, produced = 40, createdAt = 2),
        ReportEntity(assignmentId = "a1", kind = ReportKind.Shipment.raw, shipmentNumber = "1", shippedQuantity = 30, createdAt = 3),
        ReportEntity(assignmentId = "a2", kind = ReportKind.Shipment.raw, shipmentNumber = "1", shippedQuantity = 20, createdAt = 4),
    )

    private val graph = Graph(
        plants = listOf(north, south), clients = listOf(acme, beta), orders = listOf(orderA, orderB, orderC),
        assignments = listOf(a1, a2), reports = reports,
    )

    @Test fun productionRowFlattensMetrics() {
        val row = ProductionRow.of(graph, a1)
        assertEquals("A-1", row.code)
        assertEquals("Acme, S.A.", row.client)
        assertEquals("Norte", row.plant)
        assertEquals(CutStatus.OnTable, row.status)
        assertEquals(90, row.realCut)
        assertEquals(40, row.produced)
        assertEquals(60, row.toShip) // real cut 90 − 30 shipped
        assertEquals(1000.0, row.revenue, 0.001)
    }

    @Test fun filtersByPlantClientStatusPendingAndDates() {
        val all = graph.assignments
        fun ids(f: ProductionFilter) = productionRows(graph, all, f, ProductionSort.Code, false).map { it.id }
        assertEquals(listOf("a1", "a2"), ids(ProductionFilter()))
        assertEquals(listOf("a2"), ids(ProductionFilter(plantId = "p2")))
        assertEquals(listOf("a1"), ids(ProductionFilter(clientId = "c1")))
        assertEquals(listOf("a2"), ids(ProductionFilter(status = CutStatus.Waiting)))
        assertEquals(listOf("a1"), ids(ProductionFilter(onlyPending = true))) // a2 shipped 20 of 20
        assertEquals(listOf("a1"), ids(ProductionFilter(from = today, to = today.plusDays(5))))
        assertEquals(listOf("a1"), ids(ProductionFilter(query = "acme")))
        assertTrue(ProductionFilter(onlyPending = true).isActive)
        assertTrue(!ProductionFilter().isActive)
    }

    @Test fun sortsAscendingAndDescending() {
        val all = graph.assignments
        assertEquals(listOf("a2", "a1"), productionRows(graph, all, ProductionFilter(), ProductionSort.ClientDate, false).map { it.id })
        assertEquals(listOf("a1", "a2"), productionRows(graph, all, ProductionFilter(), ProductionSort.ClientDate, true).map { it.id })
        assertEquals(listOf("a2", "a1"), productionRows(graph, all, ProductionFilter(), ProductionSort.Quantity, false).map { it.id })
        assertEquals(listOf("a1", "a2"), productionRows(graph, all, ProductionFilter(), ProductionSort.ToShip, true).map { it.id })
        assertEquals(listOf("a1", "a2"), productionRows(graph, all, ProductionFilter(), ProductionSort.Plant, false).map { it.id })
    }

    @Test fun missingClientDateSortsLast() {
        val g = Graph(plants = listOf(north), orders = listOf(orderA, orderC), assignments = listOf(
            a1, AssignmentEntity(id = "a3", orderId = "o3", plantId = "p1", quantity = 10, unitPrice = 5.0, scheduledDate = null),
        ))
        assertEquals(listOf("a1", "a3"), productionRows(g, g.assignments, ProductionFilter(), ProductionSort.ClientDate, false).map { it.id })
    }

    @Test fun csvHasIosColumnsEscapingAndBom() {
        val rows = productionRows(graph, graph.assignments, ProductionFilter(), ProductionSort.Code, false)
        val lines = ProductionCsv.build(rows).split("\n")
        assertEquals(
            "Corte,Lista,Cliente,Estilo,Prenda,Planta,Estado,Cantidad,Cortadas,Producidas,Plancha,Empaque,Bodega,Enviadas,Por enviar,Ingreso,Fecha interna,Fecha cliente",
            lines[0],
        )
        assertEquals("A-1,L1,\"Acme, S.A.\",Sin estilo,Falda,Norte,En mesa de corte,100,90,40,0,0,0,30,60,1000.00,2026-10-15,2026-10-18", lines[1])
        assertEquals("B-2,,Beta,Sin estilo,,Sur,En espera,20,0,0,0,0,0,20,0,400.00,,2026-10-13", lines[2])
        assertEquals("\"say \"\"hi\"\"\"", ProductionCsv.escape("say \"hi\""))
        val bytes = ProductionCsv.bytes(rows)
        assertEquals(listOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte()), bytes.take(3))
    }

    @Test fun calendarGridStartsOnMonday() {
        // October 2026 starts on a Thursday → 3 leading blanks.
        val october = CalendarMath.gridDays(YearMonth.of(2026, 10))
        assertEquals(3 + 31, october.size)
        assertTrue(october.take(3).all { it == null })
        assertEquals(LocalDate.of(2026, 10, 1), october[3])
        // June 2026 starts on a Monday → no blanks.
        assertEquals(LocalDate.of(2026, 6, 1), CalendarMath.gridDays(YearMonth.of(2026, 6)).first())
        // February 2026 starts on Sunday → 6 blanks.
        assertEquals(6, CalendarMath.gridDays(YearMonth.of(2026, 2)).takeWhile { it == null }.size)
        // Sunday-first variant.
        assertEquals(4, CalendarMath.gridDays(YearMonth.of(2026, 10), DayOfWeek.SUNDAY).takeWhile { it == null }.size)
        val symbols = CalendarMath.weekdaySymbols()
        assertEquals(7, symbols.size)
        assertTrue(symbols.first().lowercase().startsWith("lun"))
        assertTrue(symbols.last().lowercase().startsWith("dom"))
    }

    @Test fun calendarEventsForMonthAndPlant() {
        val events = CalendarEvent.forMonth(graph, YearMonth.from(today), null)
        assertEquals(setOf("p-a1", "p-a2", "d-o1", "d-o2"), events.map { it.id }.toSet())
        val north = CalendarEvent.forMonth(graph, YearMonth.from(today), "p1")
        assertEquals(setOf("p-a1", "d-o1"), north.map { it.id }.toSet())
        assertTrue(CalendarEvent.forMonth(graph, YearMonth.from(today).plusMonths(1), null).isEmpty())
    }

    @Test fun orderFiltersAndSort() {
        // orderA fully assigned, orderB partially (20/50), orderC unassigned.
        assertEquals(listOf("o2", "o3"), graph.orders.filter { OrderFilter.Pending.matches(graph, it) }.map { it.id })
        assertEquals(listOf("o1"), graph.orders.filter { OrderFilter.Assigned.matches(graph, it) }.map { it.id })
        assertEquals(3, graph.orders.count { OrderFilter.All.matches(graph, it) })
        assertEquals(listOf("o2", "o1", "o3"), sortedOrders(graph.orders).map { it.id })
    }

    @Test fun bestFitPicksMostRoomThatFits() {
        // Norte has 100k − 1k used; Sur has 50k − 400 used.
        assertEquals("p1", bestFitPlant(graph, graph.plants, today, 500.0)?.id)
        // Nothing fits 1M: fall back to the first plant.
        assertEquals("p1", bestFitPlant(graph, graph.plants, today, 1_000_000.0)?.id)
        assertNull(bestFitPlant(graph, emptyList(), today, 1.0))
        val tight = Graph(plants = listOf(PlantEntity(id = "x", name = "A", maxCapacity = 10.0), south))
        assertEquals("p2", bestFitPlant(tight, tight.plants, today, 20.0)?.id)
    }

    @Test fun urgentGroupsSplitOverdueAndUpcoming() {
        val extra = AssignmentEntity(id = "a4", orderId = "o2", plantId = "p2", quantity = 10, unitPrice = 20.0, scheduledDate = today.toEpochMillis())
        val g = Graph(plants = graph.plants, clients = graph.clients, orders = graph.orders, assignments = graph.assignments + extra, reports = reports)
        val groups = UrgentGroups.of(g, g.assignments, windowDays = 7, today = today)
        assertEquals(listOf("a4"), groups.overdue.map { it.id }) // a2 already fully shipped
        assertEquals(listOf("a1"), groups.upcoming.map { it.id })
        assertTrue(UrgentGroups.of(g, g.assignments, windowDays = 2, today = today).upcoming.isEmpty())
    }
}
