package com.nevutech.trama.core.data

import androidx.annotation.StringRes
import androidx.room.withTransaction
import com.nevutech.trama.R
import com.nevutech.trama.core.domain.AssignmentMetrics
import com.nevutech.trama.core.domain.AssignmentRules
import com.nevutech.trama.core.domain.CapacityLedger
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.Fmt
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.l10n.L10n
import java.time.LocalDate

/** Thrown for business-rule violations; [message] is user-facing Spanish copy. */
/** A rule violation shown to the user as is; [message] is already in the app's language. */
class ServiceException(message: String) : Exception(message) {
    constructor(@StringRes id: Int, vararg args: Any) : this(L10n.str(id, *args))
}

/**
 * All production writes go through here (port of ios ProductionService.swift) so the rules live
 * in one place. [author] is stamped on reports and orders.
 */
class ProductionService(private val db: TramaDatabase, private val author: String?) {
    private val dao = db.dao()

    // Orders

    suspend fun saveOrder(
        existing: CutOrderEntity?, code: String, list: String, garment: String, quantity: Long, unitPrice: Double,
        clientId: String?, styleId: String?, internalDate: LocalDate?, clientDate: LocalDate?, notes: String?,
    ): CutOrderEntity = db.withTransaction {
        if (code.isBlank()) throw ServiceException(R.string.error_order_code_required)
        if (quantity <= 0) throw ServiceException(R.string.error_quantity_positive)
        if (unitPrice < 0) throw ServiceException(R.string.error_price_negative)
        if (existing != null) {
            val assigned = dao.assignmentsOfOrder(existing.id).sumOf { it.quantity }
            if (quantity < assigned) throw ServiceException(L10n.plural(R.plurals.error_quantity_below_assigned, assigned.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(), Fmt.int(assigned)))
        }
        val order = (existing ?: CutOrderEntity(code = "", quantity = 0, unitPrice = 0.0)).copy(
            code = code.trim(), list = list.trim(), garment = garment.trim(), quantity = quantity, unitPrice = unitPrice,
            clientId = clientId, styleId = styleId, internalDate = internalDate?.toEpochMillis(),
            clientDate = clientDate?.toEpochMillis(), notes = notes?.takeIf { it.isNotBlank() }, editedBy = author, updatedAt = now(),
        )
        dao.upsert(order)
        order
    }

    suspend fun deleteOrder(order: CutOrderEntity) = db.withTransaction {
        val hasReports = dao.assignmentsOfOrder(order.id).any { dao.reportsOf(it.id).isNotEmpty() }
        if (hasReports) throw ServiceException(R.string.error_order_has_reports)
        dao.delete(order)
    }

    // Assignment

    /** Assigns part (or all) of an order to a plant for a month, enforcing pending quantity and monthly capacity. */
    suspend fun assign(orderId: String, plantId: String, quantity: Int, date: LocalDate?): AssignmentEntity = db.withTransaction {
        val order = dao.order(orderId) ?: throw ServiceException(R.string.error_order_missing)
        val plant = dao.plant(plantId) ?: throw ServiceException(R.string.error_plant_missing)
        val remaining = (order.quantity - dao.assignmentsOfOrder(order.id).sumOf { it.quantity }).toInt().coerceAtLeast(0)
        val ledger = CapacityLedger(plant.maxCapacity, dao.assignmentsOfPlant(plant.id).mapNotNull { a ->
            a.scheduledDate?.let { CapacityLedger.Booking(it.toLocalDate(), a.quantity * a.unitPrice) }
        })
        AssignmentRules.validate(quantity, order.unitPrice, remaining, date, ledger).getOrThrow()
        val assignment = AssignmentEntity(
            orderId = order.id, plantId = plant.id, quantity = quantity.toLong(), unitPrice = order.unitPrice,
            scheduledDate = date!!.toEpochMillis(), cuttingStatus = CutStatus.Waiting.raw,
        )
        dao.upsert(assignment)
        dao.upsert(order.copy(editedBy = author, updatedAt = now()))
        assignment
    }

    suspend fun unassign(assignment: AssignmentEntity) = db.withTransaction {
        if (dao.reportsOf(assignment.id).isNotEmpty()) throw ServiceException(R.string.error_assignment_has_reports)
        dao.delete(assignment)
    }

    // Reports

    data class PlantReportInput(
        val operators: Int = 0, val absences: Int = 0, val produced: Int = 0,
        val ironing: Int = 0, val packing: Int = 0, val warehouse: Int = 0,
    )

    suspend fun savePlantReport(input: PlantReportInput, assignmentId: String, editing: ReportEntity? = null) = db.withTransaction {
        val base = editing ?: newReport(ReportKind.Plant, assignmentId)
        finish(base.copy(
            operators = input.operators.toLong(), absences = input.absences.toLong(), produced = input.produced.toLong(),
            ironing = input.ironing.toLong(), packing = input.packing.toLong(), warehouse = input.warehouse.toLong(),
        ))
    }

    /** Only one cut report per assignment. Creating a second fails; editing the existing one is allowed. */
    suspend fun saveCutReport(status: CutStatus, realQuantity: Int, assignmentId: String, editing: ReportEntity? = null) = db.withTransaction {
        val existing = dao.reportsOf(assignmentId).firstOrNull { it.kind == ReportKind.Cut.raw }
        if (editing == null && existing != null) {
            throw ServiceException(R.string.error_cut_report_exists)
        }
        val base = editing ?: newReport(ReportKind.Cut, assignmentId)
        val assignment = dao.assignment(assignmentId) ?: throw ServiceException(R.string.error_order_missing)
        dao.upsert(assignment.copy(cuttingStatus = status.raw, updatedAt = now()))
        finish(base.copy(cutStatus = status.raw, realQuantity = realQuantity.coerceAtLeast(0).toLong()))
    }

    /** Kanban move: updates the single cut report (creating it if needed), keeping the real quantity. */
    suspend fun move(assignmentId: String, status: CutStatus) = db.withTransaction {
        val current = dao.reportsOf(assignmentId).firstOrNull { it.kind == ReportKind.Cut.raw }
        saveCutReport(status, current?.realQuantity?.toInt() ?: 0, assignmentId, current)
    }

    suspend fun saveShipmentReport(number: String, quantity: Int, assignmentId: String, editing: ReportEntity? = null) = db.withTransaction {
        if (number.isBlank() || quantity <= 0) throw ServiceException(R.string.error_shipment_fields)
        val base = editing ?: newReport(ReportKind.Shipment, assignmentId)
        finish(base.copy(shipmentNumber = number.trim(), shippedQuantity = quantity.toLong()))
    }

    suspend fun deleteReport(report: ReportEntity) = db.withTransaction {
        if (report.kind == ReportKind.Cut.raw) {
            dao.assignment(report.assignmentId)?.let { dao.upsert(it.copy(cuttingStatus = CutStatus.Waiting.raw, updatedAt = now())) }
        }
        dao.delete(report)
    }

    private fun newReport(kind: ReportKind, assignmentId: String) =
        ReportEntity(assignmentId = assignmentId, kind = kind.raw, authorName = author)

    private suspend fun finish(report: ReportEntity): ReportEntity {
        val stamped = report.copy(updatedAt = now())
        dao.upsert(stamped)
        dao.assignment(report.assignmentId)?.let { dao.upsert(it.copy(updatedAt = now())) }
        return stamped
    }

    // Guarded deletes

    suspend fun deletePlant(plant: PlantEntity) = db.withTransaction {
        if (dao.assignmentsOfPlant(plant.id).isNotEmpty()) throw ServiceException(R.string.error_plant_has_assignments)
        dao.delete(plant)
    }

    suspend fun deleteClient(client: ClientEntity) = db.withTransaction {
        if (dao.orderCountOfClient(client.id) > 0) throw ServiceException(R.string.error_client_has_orders)
        dao.delete(client)
    }

    companion object {
        /** Metrics for an assignment straight from its rows (used in tests and services). */
        fun metrics(assignment: AssignmentEntity, reports: List<ReportEntity>) =
            AssignmentMetrics.of(assignment.quantity.toInt(), assignment.unitPrice, reports.map { it.snapshot() })
    }
}
