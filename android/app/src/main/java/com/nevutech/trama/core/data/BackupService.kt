package com.nevutech.trama.core.data

import androidx.annotation.PluralsRes
import androidx.annotation.StringRes
import androidx.room.withTransaction
import com.nevutech.trama.BuildConfig
import com.nevutech.trama.R
import com.nevutech.trama.core.domain.CutStatus
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.ReportKind
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.l10n.L10n
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Base64
import java.util.UUID
import kotlinx.coroutines.flow.first
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.encodeToJsonElement

/**
 * Versioned JSON backup of the whole database, byte-compatible with
 * ios/Trama/Core/Services/BackupService.swift: same keys (sorted, like `JSONEncoder.sortedKeys`),
 * uppercase UUIDs, ISO-8601 UTC dates with milliseconds, images as base64 inside the file and
 * absent keys for nil values. Every DTO field is optional so older/newer files decode.
 */
object BackupService {
    const val FORMAT_VERSION = 1

    sealed class BackupError : Exception() {
        data object InvalidFile : BackupError() {
            override val message: String get() = L10n.str(R.string.backup_error_invalid_file)
        }
        data class UnsupportedVersion(val version: Int) : BackupError() {
            override val message: String get() = L10n.str(R.string.backup_error_unsupported_version, version)
        }
    }

    /** One row count of a backup: [plural] words it with its number ("3 plantas"). */
    data class Count(@StringRes val label: Int, @PluralsRes val plural: Int, val value: Int)

    /** Lightweight description shown before a destructive restore. */
    data class Summary(val exportedAt: Instant?, val appVersion: String?, val items: List<Count>) {
        /** (label, count) in the app's language, e.g. "Plantas" to 3. */
        val counts: List<Pair<String, Int>> get() = items.map { L10n.str(it.label) to it.value }
        val total: Int get() = items.sumOf { it.value }
    }

    val appVersion: String get() = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

    /** "Trama-respaldo-2026-10-24.json" */
    fun filename(date: LocalDate = LocalDate.now()): String = "Trama-respaldo-$date.json"

    private val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        encodeDefaults = true
        isLenient = false
    }

    // Export

    suspend fun export(db: TramaDatabase, images: ImageStore, now: Instant = Instant.now(), version: String = appVersion): ByteArray {
        val dao = db.dao()
        val ids = IdMap()
        fun image(name: String?) = images.read(name)?.let { Base64.getEncoder().encodeToString(it) }

        val file = BackupFile(
            formatVersion = FORMAT_VERSION,
            exportedAt = formatDate(now.toEpochMilli()),
            appVersion = version,
            plants = dao.plants().first().map {
                PlantDTO(ids[it.id], it.remoteId, it.name, it.maxCapacity, formatDate(it.createdAt), formatDate(it.updatedAt))
            },
            clients = dao.clients().first().map {
                ClientDTO(ids[it.id], it.remoteId, it.name, it.address, formatDate(it.createdAt), formatDate(it.updatedAt))
            },
            suppliers = dao.suppliers().first().map {
                SupplierDTO(ids[it.id], it.remoteId, it.name, it.address, formatDate(it.createdAt), formatDate(it.updatedAt))
            },
            contacts = dao.contacts().first().map {
                ContactDTO(ids[it.id], it.name, it.email, it.phone, it.role, it.sortIndex, it.clientId?.let(ids::get), it.supplierId?.let(ids::get))
            },
            styles = dao.styles().first().map {
                StyleDTO(ids[it.id], it.remoteId, it.name, image(it.imageFile), formatDate(it.createdAt), formatDate(it.updatedAt))
            },
            orders = dao.orders().first().map {
                CutOrderDTO(
                    ids[it.id], it.remoteId, it.code, it.list, it.garment, it.quantity, it.unitPrice,
                    it.internalDate?.let(::formatDate), it.clientDate?.let(::formatDate), it.editedBy, it.notes,
                    formatDate(it.createdAt), formatDate(it.updatedAt), it.clientId?.let(ids::get), it.styleId?.let(ids::get),
                )
            },
            assignments = dao.assignments().first().map {
                AssignmentDTO(
                    ids[it.id], it.remoteId, it.quantity, it.unitPrice, it.scheduledDate?.let(::formatDate), it.cuttingStatus,
                    formatDate(it.createdAt), formatDate(it.updatedAt), ids[it.orderId], it.plantId?.let(ids::get),
                )
            },
            reports = dao.reports().first().map {
                ProductionReportDTO(
                    ids[it.id], it.remoteId, it.kind, it.cutStatus, it.authorName, it.operators, it.absences, it.produced,
                    it.ironing, it.packing, it.warehouse, it.realQuantity, it.shipmentNumber, it.shippedQuantity,
                    formatDate(it.createdAt), formatDate(it.updatedAt), ids[it.assignmentId],
                )
            },
            projects = dao.projects().first().map {
                ProjectDTO(
                    ids[it.id], it.remoteId, it.clientName, it.quantity, it.price, it.minutes, it.fabric,
                    it.deliveryDate?.let(::formatDate), it.notes, image(it.photoFile), it.status,
                    formatDate(it.createdAt), formatDate(it.updatedAt), it.clientId?.let(ids::get),
                )
            },
            users = dao.users().first().map {
                AppUserDTO(
                    ids[it.id], it.remoteId, it.email, it.firstName, it.lastName, it.phone, it.role, it.isActive,
                    it.passwordHash, it.passwordSalt, image(it.avatarFile), formatDate(it.createdAt), formatDate(it.updatedAt),
                    it.plantId?.let(ids::get),
                )
            },
        )
        return json.encodeToString(JsonElement.serializer(), sorted(json.encodeToJsonElement(file))).toByteArray(Charsets.UTF_8)
    }

    // Inspect / restore

    /** Decodes and validates a backup without touching the database. */
    fun inspect(bytes: ByteArray): Summary = summarize(decode(bytes))

    private fun summarize(file: BackupFile): Summary {
        return Summary(
            exportedAt = file.exportedAt?.let { Instant.ofEpochMilli(parseDate(it)) },
            appVersion = file.appVersion,
            items = listOf(
                Count(R.string.backup_count_plants, R.plurals.backup_count_plants, file.plants.size()),
                Count(R.string.backup_count_clients, R.plurals.backup_count_clients, file.clients.size()),
                Count(R.string.backup_count_suppliers, R.plurals.backup_count_suppliers, file.suppliers.size()),
                Count(R.string.backup_count_styles, R.plurals.backup_count_styles, file.styles.size()),
                Count(R.string.backup_count_orders, R.plurals.backup_count_orders, file.orders.size()),
                Count(R.string.backup_count_assignments, R.plurals.backup_count_assignments, file.assignments.size()),
                Count(R.string.backup_count_reports, R.plurals.backup_count_reports, file.reports.size()),
                Count(R.string.backup_count_projects, R.plurals.backup_count_projects, file.projects.size()),
                Count(R.string.backup_count_users, R.plurals.backup_count_users, file.users.size()),
            ),
        )
    }

    /**
     * Replaces the whole database with the backup. The file is fully decoded and converted to
     * rows before anything is erased, and erase + inserts share one transaction, so a bad file
     * never destroys local data.
     */
    suspend fun restore(bytes: ByteArray, db: TramaDatabase, images: ImageStore): Summary {
        val file = decode(bytes)
        val summary = summarize(file)
        val rows = Rows.from(file)
        val dao = db.dao()

        val previousImages = dao.styles().first().mapNotNull { it.imageFile } +
            dao.projects().first().mapNotNull { it.photoFile } + dao.users().first().mapNotNull { it.avatarFile }

        // Images are written first; rows reference the new file names.
        val written = mutableListOf<String>()
        fun store(data: ByteArray?): String? = data?.let { saveRaw(images, it) }?.also(written::add)
        try {
            db.withTransaction {
                clearTables(db)
                rows.plants.forEach { dao.upsert(it) }
                rows.clients.forEach { dao.upsert(it) }
                rows.suppliers.forEach { dao.upsert(it) }
                rows.contacts.forEach { dao.upsert(it) }
                rows.styles.forEach { (row, data) -> dao.upsert(row.copy(imageFile = store(data))) }
                rows.orders.forEach { dao.upsert(it) }
                rows.assignments.forEach { dao.upsert(it) }
                rows.reports.forEach { dao.upsert(it) }
                rows.projects.forEach { (row, data) -> dao.upsert(row.copy(photoFile = store(data))) }
                rows.users.forEach { (row, data) -> dao.upsert(row.copy(avatarFile = store(data))) }
            }
        } catch (e: Exception) {
            written.forEach(images::delete)
            throw e
        }
        previousImages.forEach(images::delete)
        return summary
    }

    /** Stores [data] untouched so restored images match the backup byte for byte. */
    private fun saveRaw(images: ImageStore, data: ByteArray): String {
        return images.saveRaw(data)
    }

    // Coding

    private fun decode(bytes: ByteArray): BackupFile {
        val file = try {
            json.decodeFromString(BackupFile.serializer(), bytes.toString(Charsets.UTF_8))
        } catch (e: Exception) {
            throw BackupError.InvalidFile
        }
        val version = file.formatVersion ?: throw BackupError.InvalidFile
        if (version < 1) throw BackupError.InvalidFile
        if (version > FORMAT_VERSION) throw BackupError.UnsupportedVersion(version)
        return file
    }

    private val isoMillis: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC)

    /** Same output as iOS `ISO8601DateFormatter` with `.withFractionalSeconds`: "2026-10-24T18:03:12.345Z". */
    fun formatDate(epochMillis: Long): String = isoMillis.format(Instant.ofEpochMilli(epochMillis))

    /** Accepts dates with or without fractional seconds and any UTC offset. */
    fun parseDate(raw: String): Long = try {
        OffsetDateTime.parse(raw, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant().toEpochMilli()
    } catch (e: Exception) {
        throw BackupError.InvalidFile
    }

    private fun sorted(element: JsonElement): JsonElement = when (element) {
        is JsonObject -> JsonObject(element.toSortedMap().mapValues { sorted(it.value) })
        is JsonArray -> JsonArray(element.map(::sorted))
        else -> element
    }

    private fun List<*>?.size() = this?.size ?: 0

    /** iOS ids are uppercase UUIDs; Android rows use lowercase. Non-UUID ids get a stable generated one. */
    private class IdMap {
        private val generated = HashMap<String, String>()
        operator fun get(id: String): String =
            runCatching { UUID.fromString(id).toString().uppercase() }.getOrNull()
                ?: generated.getOrPut(id) { UUID.randomUUID().toString().uppercase() }
    }

    /** Fully converted rows, built before the database is touched. */
    private class Rows(
        val plants: List<PlantEntity>,
        val clients: List<ClientEntity>,
        val suppliers: List<SupplierEntity>,
        val contacts: List<ContactEntity>,
        val styles: List<Pair<StyleEntity, ByteArray?>>,
        val orders: List<CutOrderEntity>,
        val assignments: List<AssignmentEntity>,
        val reports: List<ReportEntity>,
        val projects: List<Pair<ProjectEntity, ByteArray?>>,
        val users: List<Pair<UserEntity, ByteArray?>>,
    ) {
        companion object {
            fun from(f: BackupFile): Rows {
                val stamp = now()
                fun id(raw: String?): String = raw?.let(::uuid) ?: newId()
                fun date(raw: String?): Long? = raw?.let(::parseDate)
                fun created(raw: String?) = date(raw) ?: stamp
                fun image(raw: String?): ByteArray? = raw?.let {
                    try { Base64.getDecoder().decode(it) } catch (e: IllegalArgumentException) { throw BackupError.InvalidFile }
                }

                val plants = f.plants.orEmpty().map {
                    PlantEntity(id(it.id), it.name.orEmpty(), it.maxCapacity ?: 0.0, it.remoteID ?: 0, created(it.createdAt), created(it.updatedAt))
                }
                val clients = f.clients.orEmpty().map {
                    ClientEntity(id(it.id), it.name.orEmpty(), it.address, it.remoteID ?: 0, created(it.createdAt), created(it.updatedAt))
                }
                val suppliers = f.suppliers.orEmpty().map {
                    SupplierEntity(id(it.id), it.name.orEmpty(), it.address, it.remoteID ?: 0, created(it.createdAt), created(it.updatedAt))
                }
                val plantIds = plants.map { it.id }.toSet()
                val clientIds = clients.map { it.id }.toSet()
                val supplierIds = suppliers.map { it.id }.toSet()
                fun ref(raw: String?, known: Set<String>) = raw?.let(::uuid)?.takeIf { it in known }

                val contacts = f.contacts.orEmpty().map {
                    ContactEntity(
                        id(it.id), it.name, it.role, it.email, it.phone, it.sortIndex ?: 0,
                        ref(it.clientID, clientIds), ref(it.supplierID, supplierIds),
                    )
                }
                val styles = f.styles.orEmpty().map {
                    StyleEntity(id(it.id), it.name.orEmpty(), null, it.remoteID ?: 0, created(it.createdAt), created(it.updatedAt)) to image(it.imageData)
                }
                val styleIds = styles.map { it.first.id }.toSet()
                val orders = f.orders.orEmpty().map {
                    CutOrderEntity(
                        id = id(it.id), code = it.code.orEmpty(), list = it.list.orEmpty(), garment = it.garment.orEmpty(),
                        quantity = it.quantity ?: 0, unitPrice = it.unitPrice ?: 0.0, internalDate = date(it.internalDate),
                        clientDate = date(it.clientDate), notes = it.notes, editedBy = it.editedBy,
                        clientId = ref(it.clientID, clientIds), styleId = ref(it.styleID, styleIds),
                        remoteId = it.remoteID ?: 0, createdAt = created(it.createdAt), updatedAt = created(it.updatedAt),
                    )
                }
                val orderIds = orders.map { it.id }.toSet()
                // Room requires an order for every assignment (iOS allows orphans); orphans are dropped.
                val assignments = f.assignments.orEmpty().mapNotNull {
                    val orderId = ref(it.orderID, orderIds) ?: return@mapNotNull null
                    AssignmentEntity(
                        id = id(it.id), orderId = orderId, plantId = ref(it.plantID, plantIds), quantity = it.quantity ?: 0,
                        unitPrice = it.unitPrice ?: 0.0, scheduledDate = date(it.scheduledDate),
                        cuttingStatus = it.cuttingStatusRaw ?: CutStatus.Waiting.raw,
                        remoteId = it.remoteID ?: 0, createdAt = created(it.createdAt), updatedAt = created(it.updatedAt),
                    )
                }
                val assignmentIds = assignments.map { it.id }.toSet()
                val reports = f.reports.orEmpty().mapNotNull {
                    val assignmentId = ref(it.assignmentID, assignmentIds) ?: return@mapNotNull null
                    ReportEntity(
                        id = id(it.id), assignmentId = assignmentId, kind = it.kindRaw ?: ReportKind.Plant.raw,
                        authorName = it.authorName, operators = it.operators ?: 0, absences = it.absences ?: 0,
                        produced = it.produced ?: 0, ironing = it.ironing ?: 0, packing = it.packing ?: 0,
                        warehouse = it.warehouse ?: 0, cutStatus = it.cutStatusRaw, realQuantity = it.realQuantity ?: 0,
                        shipmentNumber = it.shipmentNumber, shippedQuantity = it.shippedQuantity ?: 0,
                        remoteId = it.remoteID ?: 0, createdAt = created(it.createdAt), updatedAt = created(it.updatedAt),
                    )
                }
                val projects = f.projects.orEmpty().map {
                    ProjectEntity(
                        id = id(it.id), clientName = it.clientName, clientId = ref(it.clientID, clientIds), quantity = it.quantity ?: 0,
                        price = it.price ?: 0.0, minutes = it.minutes ?: 0.0, fabric = it.fabric,
                        status = it.statusRaw ?: ProjectStatus.Pending.raw, deliveryDate = date(it.deliveryDate), notes = it.notes,
                        remoteId = it.remoteID ?: 0, createdAt = created(it.createdAt), updatedAt = created(it.updatedAt),
                    ) to image(it.photoData)
                }
                // Emails are unique on Android; a user without one (or a duplicate) can't sign in, so it is dropped.
                val emails = HashSet<String>()
                val users = f.users.orEmpty().mapNotNull {
                    val email = it.email?.trim()?.lowercase()?.takeIf(String::isNotEmpty) ?: return@mapNotNull null
                    if (!emails.add(email)) return@mapNotNull null
                    UserEntity(
                        id = id(it.id), firstName = it.firstName.orEmpty(), lastName = it.lastName.orEmpty(), email = email,
                        phone = it.phone.orEmpty(), role = it.roleRaw ?: Role.PlantManager.raw, passwordHash = it.passwordHash,
                        passwordSalt = it.passwordSalt, isActive = it.isActive ?: true, plantId = ref(it.plantID, plantIds),
                        remoteId = it.remoteID ?: 0, createdAt = created(it.createdAt), updatedAt = created(it.updatedAt),
                    ) to image(it.avatarData)
                }
                return Rows(plants, clients, suppliers, contacts, styles, orders, assignments, reports, projects, users)
            }

            private fun uuid(raw: String): String = try {
                UUID.fromString(raw).toString()
            } catch (e: IllegalArgumentException) {
                throw BackupError.InvalidFile
            }
        }
    }
}

// DTOs: field names are the iOS Codable keys. Dates are ISO-8601 strings, images base64 strings.

@Serializable
internal data class BackupFile(
    val formatVersion: Int? = null,
    val exportedAt: String? = null,
    val appVersion: String? = null,
    val plants: List<PlantDTO>? = null,
    val clients: List<ClientDTO>? = null,
    val suppliers: List<SupplierDTO>? = null,
    val contacts: List<ContactDTO>? = null,
    val styles: List<StyleDTO>? = null,
    val orders: List<CutOrderDTO>? = null,
    val assignments: List<AssignmentDTO>? = null,
    val reports: List<ProductionReportDTO>? = null,
    val projects: List<ProjectDTO>? = null,
    val users: List<AppUserDTO>? = null,
)

@Serializable
internal data class PlantDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val name: String? = null,
    val maxCapacity: Double? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

@Serializable
internal data class ClientDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val name: String? = null,
    val address: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

@Serializable
internal data class SupplierDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val name: String? = null,
    val address: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

@Serializable
internal data class ContactDTO(
    val id: String? = null,
    val name: String? = null,
    val email: String? = null,
    val phone: String? = null,
    val role: String? = null,
    val sortIndex: Int? = null,
    val clientID: String? = null,
    val supplierID: String? = null,
)

@Serializable
internal data class StyleDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val name: String? = null,
    val imageData: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

@Serializable
internal data class CutOrderDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val code: String? = null,
    val list: String? = null,
    val garment: String? = null,
    val quantity: Long? = null,
    val unitPrice: Double? = null,
    val internalDate: String? = null,
    val clientDate: String? = null,
    val editedBy: String? = null,
    val notes: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val clientID: String? = null,
    val styleID: String? = null,
)

@Serializable
internal data class AssignmentDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val quantity: Long? = null,
    val unitPrice: Double? = null,
    val scheduledDate: String? = null,
    val cuttingStatusRaw: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val orderID: String? = null,
    val plantID: String? = null,
)

@Serializable
internal data class ProductionReportDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val kindRaw: String? = null,
    val cutStatusRaw: String? = null,
    val authorName: String? = null,
    val operators: Long? = null,
    val absences: Long? = null,
    val produced: Long? = null,
    val ironing: Long? = null,
    val packing: Long? = null,
    val warehouse: Long? = null,
    val realQuantity: Long? = null,
    val shipmentNumber: String? = null,
    val shippedQuantity: Long? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val assignmentID: String? = null,
)

@Serializable
internal data class ProjectDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val clientName: String? = null,
    val quantity: Long? = null,
    val price: Double? = null,
    val minutes: Double? = null,
    val fabric: String? = null,
    val deliveryDate: String? = null,
    val notes: String? = null,
    val photoData: String? = null,
    val statusRaw: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val clientID: String? = null,
)

@Serializable
internal data class AppUserDTO(
    val id: String? = null,
    val remoteID: Long? = null,
    val email: String? = null,
    val firstName: String? = null,
    val lastName: String? = null,
    val phone: String? = null,
    val roleRaw: String? = null,
    val isActive: Boolean? = null,
    val passwordHash: String? = null,
    val passwordSalt: String? = null,
    val avatarData: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val plantID: String? = null,
)
