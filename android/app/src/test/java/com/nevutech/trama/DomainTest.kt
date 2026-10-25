package com.nevutech.trama

import com.nevutech.trama.core.domain.AppSection
import com.nevutech.trama.core.domain.AssignmentError
import com.nevutech.trama.core.domain.AssignmentMetrics
import com.nevutech.trama.core.domain.AssignmentRules
import com.nevutech.trama.core.domain.CalculatorConstants
import com.nevutech.trama.core.domain.CalculatorEngine
import com.nevutech.trama.core.domain.CalculatorInput
import com.nevutech.trama.core.domain.CalculatorResult
import com.nevutech.trama.core.domain.CapacityLedger
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.ProductionTotals
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.ReportSnapshot
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.domain.UrgencyPolicy
import com.nevutech.trama.core.domain.UserPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.YearMonth

/** 1:1 port of ios/TramaTests/DomainTests.swift: both platforms must agree on every rule. */
class DomainTest {
    private val t0 = 1_700_000_000_000L

    @Test fun metricsUseLatestPlantReportAndSumShipments() {
        val m = AssignmentMetrics.of(500, 10.0, listOf(
            ReportSnapshot(ReportKind.Plant, t0, operators = 10, produced = 100),
            ReportSnapshot(ReportKind.Plant, t0 + 60_000, operators = 12, produced = 250, warehouse = 40),
            ReportSnapshot(ReportKind.Shipment, t0, shippedQuantity = 30),
            ReportSnapshot(ReportKind.Shipment, t0 + 5_000, shippedQuantity = 20),
            ReportSnapshot(ReportKind.Cut, t0, cutStatus = CutStatus.Ready, realQuantity = 480),
        ))
        assertEquals(250, m.produced); assertEquals(12, m.operators); assertEquals(40, m.warehouse)
        assertEquals(50, m.shipped); assertEquals(480, m.realCut); assertEquals(CutStatus.Ready, m.cutStatus)
        assertEquals(480, m.shippingBase); assertEquals(430, m.toShip); assertEquals(5_000.0, m.revenue, 0.0)
    }

    @Test fun toShipFallsBackToPlannedAndNeverGoesNegative() {
        val m = AssignmentMetrics.of(100, 1.0, listOf(ReportSnapshot(ReportKind.Shipment, t0, shippedQuantity = 150)))
        assertEquals(100, m.shippingBase); assertEquals(0, m.toShip); assertTrue(m.isComplete); assertEquals(1.0, m.shippingProgress, 0.0)
    }

    @Test fun totalsAggregate() {
        val a = AssignmentMetrics.of(100, 2.0, listOf(ReportSnapshot(ReportKind.Plant, t0, produced = 40, ironing = 5)))
        val b = AssignmentMetrics.of(50, 4.0, listOf(ReportSnapshot(ReportKind.Shipment, t0, shippedQuantity = 10)))
        val t = ProductionTotals.of(listOf(a, b))
        assertEquals(150, t.quantity); assertEquals(40, t.produced); assertEquals(5, t.ironing)
        assertEquals(10, t.shipped); assertEquals(140, t.toShip); assertEquals(400.0, t.revenue, 0.0)
    }

    @Test fun ledgerSumsOnlyTheSameMonth() {
        val ledger = CapacityLedger(1_000.0, listOf(
            CapacityLedger.Booking(LocalDate.of(2026, 3, 2), 300.0),
            CapacityLedger.Booking(LocalDate.of(2026, 3, 28), 200.0),
            CapacityLedger.Booking(LocalDate.of(2026, 4, 1), 999.0),
        ))
        assertEquals(500.0, ledger.used(YearMonth.of(2026, 3)), 0.0)
        assertEquals(500.0, ledger.available(YearMonth.of(2026, 3)), 0.0)
        assertEquals(0.999, ledger.utilization(YearMonth.of(2026, 4)), 1e-9)
        assertEquals(500.0, ledger.monthlyUsage(2026)[3]!!, 0.0)
        assertEquals(0.0, ledger.monthlyUsage(2026)[5]!!, 0.0)
    }

    @Test fun validateRejectsOverCapacityAndRemaining() {
        val busy = CapacityLedger(1_000.0, listOf(CapacityLedger.Booking(LocalDate.of(2026, 3, 2), 900.0)))
        assertEquals(AssignmentError.ExceedsCapacity(100.0), AssignmentRules.validate(20, 10.0, 50, LocalDate.of(2026, 3, 9), busy).exceptionOrNull())
        val free = CapacityLedger(1_000_000.0, emptyList())
        assertEquals(AssignmentError.ExceedsRemaining(50), AssignmentRules.validate(60, 1.0, 50, LocalDate.now(), free).exceptionOrNull())
        assertEquals(AssignmentError.InvalidQuantity, AssignmentRules.validate(0, 1.0, 50, LocalDate.now(), free).exceptionOrNull())
        assertEquals(AssignmentError.MissingDate, AssignmentRules.validate(10, 1.0, 50, null, free).exceptionOrNull())
        assertEquals(1_000.0, AssignmentRules.validate(10, 100.0, 10, LocalDate.of(2026, 1, 1), CapacityLedger(1_000.0, emptyList())).getOrThrow(), 0.0)
    }

    @Test fun urgency() {
        val today = LocalDate.of(2026, 10, 25)
        assertTrue(UrgencyPolicy.isUrgent(10, today.plusDays(3), today, 7))
        assertTrue(UrgencyPolicy.isUrgent(10, today.minusDays(1), today, 7))
        assertFalse(UrgencyPolicy.isUrgent(10, today.plusDays(30), today, 7))
        assertFalse(UrgencyPolicy.isUrgent(0, today.plusDays(3), today, 7))
        assertFalse(UrgencyPolicy.isUrgent(10, null, today, 7))
        assertEquals(-1, UrgencyPolicy.daysLeft(today.minusDays(1), today))
    }

    private val constants = CalculatorConstants(480.0, 2_400.0, 9_600.0, 5.0, 20.0)

    @Test fun calculatorFullComputation() {
        val r = CalculatorEngine.compute(CalculatorInput(quantity = 4_000.0, realMinutes = 12.0, clientMinutes = 15.0, operators = 30.0, pricePerStyle = 60.0, operatingExpenses = 40_000.0), constants)
        assertEquals(240_000.0, r.grossIncome!!, 0.0); assertEquals(200_000.0, r.netIncome!!, 0.0)
        assertEquals(5.0, r.pricePerRealMinute!!, 0.0); assertEquals(1_200.0, r.dailyGoal!!, 0.0)
        assertEquals(6_000.0, r.weeklyProduction!!, 0.0); assertEquals(3.3333, r.estimatedDays!!, 1e-3)
        assertEquals(0.1667, r.estimatedMonths!!, 1e-3); assertEquals(1.25, r.minuteEfficiency!!, 0.0)
    }

    @Test fun calculatorMissingInputsYieldNulls() {
        assertEquals(CalculatorResult(), CalculatorEngine.compute(CalculatorInput(), CalculatorConstants()))
        assertEquals(12.0, CalculatorEngine.compute(CalculatorInput(lineOperators = 20.0, realDailyProduction = 800.0), constants).realProductionMinute!!, 0.0)
    }

    @Test fun legacyCutStatusStrings() {
        assertEquals(CutStatus.OnTable, CutStatus.fromLegacy("En Mesa de Corte"))
        assertEquals(CutStatus.Ready, CutStatus.fromLegacy("listo para confeccionar"))
        assertEquals(CutStatus.Waiting, CutStatus.fromLegacy("en espera"))
        assertEquals(CutStatus.Waiting, CutStatus.fromLegacy(null))
    }

    @Test fun rolePermissionsMirrorLegacyMenu() {
        assertEquals(AppSection.entries, Role.Admin.sections)
        assertEquals(listOf(ReportKind.Plant), Role.PlantManager.creatableReports)
        assertTrue(AppSection.Shipments in Role.ShippingManager.sections)
        assertFalse(AppSection.Orders in Role.PlantManager.sections)
        assertEquals(AppSection.Orders, Role.CutManager.landing)
    }

    @Test fun userPolicyProtectsLastAdmin() {
        val admin = UserPolicy.Member("a", Role.Admin, true)
        val other = UserPolicy.Member("b", Role.CutManager, true)
        val members = listOf(admin, other)
        assertEquals(UserPolicy.Violation.CannotDeleteSelf, UserPolicy.violation(UserPolicy.Change.Delete, admin, "a", members))
        assertEquals(UserPolicy.Violation.LastAdmin, UserPolicy.violation(UserPolicy.Change.Delete, admin, "b", members))
        assertEquals(UserPolicy.Violation.CannotChangeOwnRole, UserPolicy.violation(UserPolicy.Change.ChangeRole(Role.CutManager), admin, "a", members))
        assertNull(UserPolicy.violation(UserPolicy.Change.Deactivate, other, "a", members))
    }
}
