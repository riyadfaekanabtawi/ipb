package com.nevutech.trama.core.data

import com.nevutech.trama.core.domain.AssignmentMetrics
import com.nevutech.trama.core.domain.CapacityLedger
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.OrderAssignmentState
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.ReportSnapshot
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.domain.UrgencyPolicy
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

fun Long.toLocalDate(): LocalDate = Instant.ofEpochMilli(this).atZone(ZoneId.systemDefault()).toLocalDate()
fun LocalDate.toEpochMillis(): Long = atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()

/**
 * Immutable, fully linked snapshot of the database. Rebuilt whenever any table changes, so
 * screens read derived values (remaining quantity, metrics, capacity) without extra queries.
 * Plays the role of the iOS `Entities+Domain.swift` conveniences.
 */
class Graph(
    val plants: List<PlantEntity> = emptyList(),
    val clients: List<ClientEntity> = emptyList(),
    val suppliers: List<SupplierEntity> = emptyList(),
    val contacts: List<ContactEntity> = emptyList(),
    val styles: List<StyleEntity> = emptyList(),
    val orders: List<CutOrderEntity> = emptyList(),
    val assignments: List<AssignmentEntity> = emptyList(),
    val reports: List<ReportEntity> = emptyList(),
    val projects: List<ProjectEntity> = emptyList(),
    val users: List<UserEntity> = emptyList(),
) {
    private val plantById = plants.associateBy { it.id }
    private val clientById = clients.associateBy { it.id }
    private val styleById = styles.associateBy { it.id }
    private val orderById = orders.associateBy { it.id }
    private val assignmentById = assignments.associateBy { it.id }
    private val reportsByAssignment = reports.groupBy { it.assignmentId }
    private val assignmentsByOrder = assignments.groupBy { it.orderId }
    private val assignmentsByPlant = assignments.groupBy { it.plantId }
    private val metricsCache = HashMap<String, AssignmentMetrics>()

    fun plant(id: String?) = id?.let(plantById::get)
    fun client(id: String?) = id?.let(clientById::get)
    fun style(id: String?) = id?.let(styleById::get)
    fun order(id: String?) = id?.let(orderById::get)
    fun assignment(id: String?) = id?.let(assignmentById::get)
    fun user(id: String?) = users.firstOrNull { it.id == id }
    fun supplier(id: String?) = suppliers.firstOrNull { it.id == id }
    fun project(id: String?) = projects.firstOrNull { it.id == id }

    // Contacts
    fun contactsOfClient(id: String) = contacts.filter { it.clientId == id }.sortedBy { it.sortIndex }
    fun contactsOfSupplier(id: String) = contacts.filter { it.supplierId == id }.sortedBy { it.sortIndex }

    // Orders
    fun assignmentsOf(order: CutOrderEntity) = assignmentsByOrder[order.id].orEmpty()
    fun assignedQuantity(order: CutOrderEntity) = assignmentsOf(order).sumOf { it.quantity }
    fun remaining(order: CutOrderEntity) = maxOf(0L, order.quantity - assignedQuantity(order))
    fun state(order: CutOrderEntity) = OrderAssignmentState.of(order.quantity, assignedQuantity(order))
    fun clientName(order: CutOrderEntity?) = client(order?.clientId)?.name ?: "Sin cliente"
    fun styleName(order: CutOrderEntity?) = style(order?.styleId)?.name ?: "Sin estilo"
    fun ordersOf(client: ClientEntity) = orders.filter { it.clientId == client.id }
    fun ordersOf(style: StyleEntity) = orders.filter { it.styleId == style.id }

    // Assignments
    fun reportsOf(assignment: AssignmentEntity) = reportsByAssignment[assignment.id].orEmpty()
    fun cutReport(assignment: AssignmentEntity) = reportsOf(assignment).firstOrNull { it.kind == ReportKind.Cut.raw }
    fun cutStatus(assignment: AssignmentEntity) = CutStatus.fromRaw(assignment.cuttingStatus) ?: CutStatus.Waiting
    fun plantName(assignment: AssignmentEntity) = plant(assignment.plantId)?.name ?: "Sin planta"
    fun orderOf(assignment: AssignmentEntity) = order(assignment.orderId)
    fun title(assignment: AssignmentEntity) = orderOf(assignment)?.code ?: "Corte"
    fun clientDate(assignment: AssignmentEntity) = orderOf(assignment)?.clientDate?.toLocalDate()

    fun metrics(assignment: AssignmentEntity): AssignmentMetrics = metricsCache.getOrPut(assignment.id) {
        AssignmentMetrics.of(assignment.quantity.toInt(), assignment.unitPrice, reportsOf(assignment).map { it.snapshot() })
    }

    fun isUrgent(assignment: AssignmentEntity, windowDays: Int, today: LocalDate = LocalDate.now()) =
        UrgencyPolicy.isUrgent(metrics(assignment).toShip, clientDate(assignment), today, windowDays)

    fun searchText(assignment: AssignmentEntity): String {
        val order = orderOf(assignment)
        return listOfNotNull(order?.code, order?.list, order?.garment, clientName(order), styleName(order), plantName(assignment), cutStatus(assignment).title)
            .joinToString(" ").lowercase()
    }

    fun searchText(order: CutOrderEntity): String =
        listOfNotNull(order.code, order.list, order.garment, clientName(order), styleName(order), order.notes).joinToString(" ").lowercase()

    // Plants
    fun assignmentsOf(plant: PlantEntity) = assignmentsByPlant[plant.id].orEmpty()
    fun managersOf(plant: PlantEntity) = users.filter { it.plantId == plant.id && Role.fromRaw(it.role) == Role.PlantManager }

    fun ledger(plant: PlantEntity) = CapacityLedger(
        maxCapacity = plant.maxCapacity,
        bookings = assignmentsOf(plant).mapNotNull { a ->
            a.scheduledDate?.let { CapacityLedger.Booking(it.toLocalDate(), metrics(a).revenue) }
        },
    )

    /** Assignments of a style grouped per plant (legacy "estilo asignado a plantas"). */
    fun plantDistribution(style: StyleEntity): List<Pair<PlantEntity, Int>> =
        ordersOf(style).flatMap(::assignmentsOf).mapNotNull { plant(it.plantId) }
            .groupingBy { it }.eachCount().toList().sortedBy { it.first.name }

    /** Plant managers only see their plant (docs/DOMAIN.md rule 8). */
    fun visibleAssignments(user: UserEntity?): List<AssignmentEntity> {
        val role = Role.fromRaw(user?.role)
        if (role != Role.PlantManager) return assignments
        val plantId = user?.plantId ?: return emptyList()
        return assignments.filter { it.plantId == plantId }
    }
}

fun ReportEntity.snapshot() = ReportSnapshot(
    kind = ReportKind.fromRaw(kind),
    createdAt = createdAt,
    operators = operators.toInt(),
    absences = absences.toInt(),
    produced = produced.toInt(),
    ironing = ironing.toInt(),
    packing = packing.toInt(),
    warehouse = warehouse.toInt(),
    cutStatus = CutStatus.fromRaw(cutStatus),
    realQuantity = realQuantity.toInt(),
    shippedQuantity = shippedQuantity.toInt(),
)

fun ReportEntity.summary(): String = when (ReportKind.fromRaw(kind)) {
    ReportKind.Plant -> "$produced producidas · $operators operarios · $absences faltas"
    ReportKind.Cut -> "${CutStatus.fromRaw(cutStatus)?.title ?: "—"} · $realQuantity cortadas"
    ReportKind.Shipment -> "Envío #${shipmentNumber ?: "—"} · $shippedQuantity prendas"
}

val UserEntity.fullName: String
    get() = "$firstName $lastName".trim().ifEmpty { email }

val UserEntity.roleValue: Role get() = Role.fromRaw(role)
val ProjectEntity.statusValue: ProjectStatus get() = ProjectStatus.fromRaw(status)
val ProjectEntity.total: Double get() = quantity * price
