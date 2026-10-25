package com.nevutech.trama.core.data.sync

import com.nevutech.trama.core.data.AppUserDTO
import com.nevutech.trama.core.data.AssignmentDTO
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.ClientDTO
import com.nevutech.trama.core.data.ClientEntity
import com.nevutech.trama.core.data.ContactDTO
import com.nevutech.trama.core.data.ContactEntity
import com.nevutech.trama.core.data.CutOrderDTO
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.PlantDTO
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.data.ProductionReportDTO
import com.nevutech.trama.core.data.ProjectDTO
import com.nevutech.trama.core.data.ProjectEntity
import com.nevutech.trama.core.data.ReportEntity
import com.nevutech.trama.core.data.StyleDTO
import com.nevutech.trama.core.data.StyleEntity
import com.nevutech.trama.core.data.SupplierDTO
import com.nevutech.trama.core.data.SupplierEntity
import com.nevutech.trama.core.data.UserEntity
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.Role
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import java.util.Base64
import java.util.UUID

/**
 * Converts rows to and from the sync payload (`data`). The payload is exactly one element of the
 * backup file (BackupService DTOs): same keys, uppercase UUIDs, ISO-8601 UTC dates with
 * milliseconds, images inline as base64, relations by id and absent keys for nil values.
 */
object SyncCodec {
    val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        encodeDefaults = true
    }

    /** Wire ids are uppercase, like iOS `UUID.uuidString` and the backup files. */
    fun wireId(id: String): String = runCatching { UUID.fromString(id).toString().uppercase() }.getOrDefault(id)

    /** Local ids are lowercase. Returns null for anything that isn't a UUID. */
    fun localId(raw: String?): String? = raw?.let { runCatching { UUID.fromString(it).toString() }.getOrNull() }

    private fun date(ms: Long) = BackupService.formatDate(ms)
    private fun parse(raw: String?): Long? = raw?.let { runCatching { BackupService.parseDate(it) }.getOrNull() }
    private fun b64(bytes: ByteArray?) = bytes?.let { Base64.getEncoder().encodeToString(it) }
    fun image(raw: String?): ByteArray? = raw?.let { runCatching { Base64.getDecoder().decode(it) }.getOrNull() }

    private fun <T> obj(serializer: KSerializer<T>, value: T): JsonObject = json.encodeToJsonElement(serializer, value).jsonObject
    private fun <T> read(serializer: KSerializer<T>, data: JsonElement): T = json.decodeFromJsonElement(serializer, data)

    // Encode (row → payload). `image` holds the bytes of the row's image file, if any.

    fun encode(p: PlantEntity) = obj(PlantDTO.serializer(), PlantDTO(wireId(p.id), p.remoteId, p.name, p.maxCapacity, date(p.createdAt), date(p.updatedAt)))
    fun encode(c: ClientEntity) = obj(ClientDTO.serializer(), ClientDTO(wireId(c.id), c.remoteId, c.name, c.address, date(c.createdAt), date(c.updatedAt)))
    fun encode(s: SupplierEntity) = obj(SupplierDTO.serializer(), SupplierDTO(wireId(s.id), s.remoteId, s.name, s.address, date(s.createdAt), date(s.updatedAt)))
    fun encode(c: ContactEntity) = obj(
        ContactDTO.serializer(),
        ContactDTO(wireId(c.id), c.name, c.email, c.phone, c.role, c.sortIndex, c.clientId?.let(::wireId), c.supplierId?.let(::wireId)),
    )
    fun encode(s: StyleEntity, image: ByteArray?) = obj(
        StyleDTO.serializer(), StyleDTO(wireId(s.id), s.remoteId, s.name, b64(image), date(s.createdAt), date(s.updatedAt)),
    )
    fun encode(o: CutOrderEntity) = obj(
        CutOrderDTO.serializer(),
        CutOrderDTO(
            wireId(o.id), o.remoteId, o.code, o.list, o.garment, o.quantity, o.unitPrice, o.internalDate?.let(::date),
            o.clientDate?.let(::date), o.editedBy, o.notes, date(o.createdAt), date(o.updatedAt),
            o.clientId?.let(::wireId), o.styleId?.let(::wireId),
        ),
    )
    fun encode(a: AssignmentEntity) = obj(
        AssignmentDTO.serializer(),
        AssignmentDTO(
            wireId(a.id), a.remoteId, a.quantity, a.unitPrice, a.scheduledDate?.let(::date), a.cuttingStatus,
            date(a.createdAt), date(a.updatedAt), wireId(a.orderId), a.plantId?.let(::wireId),
        ),
    )
    fun encode(r: ReportEntity) = obj(
        ProductionReportDTO.serializer(),
        ProductionReportDTO(
            wireId(r.id), r.remoteId, r.kind, r.cutStatus, r.authorName, r.operators, r.absences, r.produced, r.ironing,
            r.packing, r.warehouse, r.realQuantity, r.shipmentNumber, r.shippedQuantity, date(r.createdAt), date(r.updatedAt),
            wireId(r.assignmentId),
        ),
    )
    fun encode(p: ProjectEntity, image: ByteArray?) = obj(
        ProjectDTO.serializer(),
        ProjectDTO(
            wireId(p.id), p.remoteId, p.clientName, p.quantity, p.price, p.minutes, p.fabric, p.deliveryDate?.let(::date),
            p.notes, b64(image), p.status, date(p.createdAt), date(p.updatedAt), p.clientId?.let(::wireId),
        ),
    )
    fun encode(u: UserEntity, image: ByteArray?) = obj(
        AppUserDTO.serializer(),
        AppUserDTO(
            wireId(u.id), u.remoteId, u.email, u.firstName, u.lastName, u.phone, u.role, u.isActive, u.passwordHash,
            u.passwordSalt, b64(image), date(u.createdAt), date(u.updatedAt), u.plantId?.let(::wireId),
        ),
    )

    // Decode (payload → row). Relations come back as local ids; the applier checks they exist.
    // Image columns are left empty: the applier stores the bytes and fills in the file name.

    /** A decoded row plus its inline image bytes (styles, projects, users). */
    data class Decoded<T>(val row: T, val image: ByteArray? = null)

    fun plant(id: String, data: JsonElement, stamp: Long): PlantEntity = read(PlantDTO.serializer(), data).let {
        PlantEntity(id, it.name.orEmpty(), it.maxCapacity ?: 0.0, it.remoteID ?: 0, parse(it.createdAt) ?: stamp, parse(it.updatedAt) ?: stamp)
    }

    fun client(id: String, data: JsonElement, stamp: Long): ClientEntity = read(ClientDTO.serializer(), data).let {
        ClientEntity(id, it.name.orEmpty(), it.address, it.remoteID ?: 0, parse(it.createdAt) ?: stamp, parse(it.updatedAt) ?: stamp)
    }

    fun supplier(id: String, data: JsonElement, stamp: Long): SupplierEntity = read(SupplierDTO.serializer(), data).let {
        SupplierEntity(id, it.name.orEmpty(), it.address, it.remoteID ?: 0, parse(it.createdAt) ?: stamp, parse(it.updatedAt) ?: stamp)
    }

    fun contact(id: String, data: JsonElement): ContactEntity = read(ContactDTO.serializer(), data).let {
        ContactEntity(id, it.name, it.role, it.email, it.phone, it.sortIndex ?: 0, localId(it.clientID), localId(it.supplierID))
    }

    fun style(id: String, data: JsonElement, stamp: Long): Decoded<StyleEntity> = read(StyleDTO.serializer(), data).let {
        Decoded(StyleEntity(id, it.name.orEmpty(), null, it.remoteID ?: 0, parse(it.createdAt) ?: stamp, parse(it.updatedAt) ?: stamp), image(it.imageData))
    }

    fun order(id: String, data: JsonElement, stamp: Long): CutOrderEntity = read(CutOrderDTO.serializer(), data).let {
        CutOrderEntity(
            id = id, code = it.code.orEmpty(), list = it.list.orEmpty(), garment = it.garment.orEmpty(), quantity = it.quantity ?: 0,
            unitPrice = it.unitPrice ?: 0.0, internalDate = parse(it.internalDate), clientDate = parse(it.clientDate), notes = it.notes,
            editedBy = it.editedBy, clientId = localId(it.clientID), styleId = localId(it.styleID), remoteId = it.remoteID ?: 0,
            createdAt = parse(it.createdAt) ?: stamp, updatedAt = parse(it.updatedAt) ?: stamp,
        )
    }

    /** Null when the required order reference is missing or malformed (same for reports below). */
    fun assignment(id: String, data: JsonElement, stamp: Long): AssignmentEntity? = read(AssignmentDTO.serializer(), data).let {
        val orderId = localId(it.orderID) ?: return null
        AssignmentEntity(
            id = id, orderId = orderId, plantId = localId(it.plantID), quantity = it.quantity ?: 0, unitPrice = it.unitPrice ?: 0.0,
            scheduledDate = parse(it.scheduledDate), cuttingStatus = it.cuttingStatusRaw ?: CutStatus.Waiting.raw,
            remoteId = it.remoteID ?: 0, createdAt = parse(it.createdAt) ?: stamp, updatedAt = parse(it.updatedAt) ?: stamp,
        )
    }

    fun report(id: String, data: JsonElement, stamp: Long): ReportEntity? = read(ProductionReportDTO.serializer(), data).let {
        val assignmentId = localId(it.assignmentID) ?: return null
        ReportEntity(
            id = id, assignmentId = assignmentId, kind = it.kindRaw ?: ReportKind.Plant.raw, authorName = it.authorName,
            operators = it.operators ?: 0, absences = it.absences ?: 0, produced = it.produced ?: 0, ironing = it.ironing ?: 0,
            packing = it.packing ?: 0, warehouse = it.warehouse ?: 0, cutStatus = it.cutStatusRaw, realQuantity = it.realQuantity ?: 0,
            shipmentNumber = it.shipmentNumber, shippedQuantity = it.shippedQuantity ?: 0, remoteId = it.remoteID ?: 0,
            createdAt = parse(it.createdAt) ?: stamp, updatedAt = parse(it.updatedAt) ?: stamp,
        )
    }

    fun project(id: String, data: JsonElement, stamp: Long): Decoded<ProjectEntity> = read(ProjectDTO.serializer(), data).let {
        Decoded(
            ProjectEntity(
                id = id, clientName = it.clientName, clientId = localId(it.clientID), quantity = it.quantity ?: 0, price = it.price ?: 0.0,
                minutes = it.minutes ?: 0.0, fabric = it.fabric, status = it.statusRaw ?: ProjectStatus.Pending.raw,
                deliveryDate = parse(it.deliveryDate), notes = it.notes, remoteId = it.remoteID ?: 0,
                createdAt = parse(it.createdAt) ?: stamp, updatedAt = parse(it.updatedAt) ?: stamp,
            ),
            image(it.photoData),
        )
    }

    /** Null when the user has no email (it could never sign in). */
    fun user(id: String, data: JsonElement, stamp: Long): Decoded<UserEntity>? = read(AppUserDTO.serializer(), data).let {
        val email = it.email?.trim()?.lowercase()?.takeIf(String::isNotEmpty) ?: return null
        Decoded(
            UserEntity(
                id = id, firstName = it.firstName.orEmpty(), lastName = it.lastName.orEmpty(), email = email, phone = it.phone.orEmpty(),
                role = it.roleRaw ?: Role.PlantManager.raw, passwordHash = it.passwordHash, passwordSalt = it.passwordSalt,
                isActive = it.isActive ?: true, plantId = localId(it.plantID), remoteId = it.remoteID ?: 0,
                createdAt = parse(it.createdAt) ?: stamp, updatedAt = parse(it.updatedAt) ?: stamp,
            ),
            image(it.avatarData),
        )
    }
}
