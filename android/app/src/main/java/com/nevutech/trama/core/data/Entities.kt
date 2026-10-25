package com.nevutech.trama.core.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

// Room schema mirroring ios/Trama/Core/Persistence/Trama.xcdatamodeld (see docs/DOMAIN.md).
// IDs are UUID strings and timestamps epoch millis, so backups round-trip with iOS.
// Images live as files in filesDir/images; columns hold the file name only.

fun newId(): String = UUID.randomUUID().toString()
fun now(): Long = System.currentTimeMillis()

@Entity(tableName = "plant")
data class PlantEntity(
    @PrimaryKey val id: String = newId(),
    val name: String,
    val maxCapacity: Double,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(tableName = "client")
data class ClientEntity(
    @PrimaryKey val id: String = newId(),
    val name: String,
    val address: String? = null,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(tableName = "supplier")
data class SupplierEntity(
    @PrimaryKey val id: String = newId(),
    val name: String,
    val address: String? = null,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(
    tableName = "contact",
    foreignKeys = [
        ForeignKey(entity = ClientEntity::class, parentColumns = ["id"], childColumns = ["clientId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = SupplierEntity::class, parentColumns = ["id"], childColumns = ["supplierId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index("clientId"), Index("supplierId")],
)
data class ContactEntity(
    @PrimaryKey val id: String = newId(),
    val name: String? = null,
    val role: String? = null,
    val email: String? = null,
    val phone: String? = null,
    val sortIndex: Int = 0,
    val clientId: String? = null,
    val supplierId: String? = null,
)

@Entity(tableName = "style")
data class StyleEntity(
    @PrimaryKey val id: String = newId(),
    val name: String,
    val imageFile: String? = null,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(
    tableName = "cut_order",
    foreignKeys = [
        ForeignKey(entity = ClientEntity::class, parentColumns = ["id"], childColumns = ["clientId"], onDelete = ForeignKey.RESTRICT),
        ForeignKey(entity = StyleEntity::class, parentColumns = ["id"], childColumns = ["styleId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("clientId"), Index("styleId")],
)
data class CutOrderEntity(
    @PrimaryKey val id: String = newId(),
    val code: String,
    val list: String = "",
    val garment: String = "",
    val quantity: Long,
    val unitPrice: Double,
    /** Company's internal due date (legacy "fecha IPB"). Epoch millis. */
    val internalDate: Long? = null,
    /** Delivery date promised to the client. Epoch millis. */
    val clientDate: Long? = null,
    val notes: String? = null,
    val editedBy: String? = null,
    val clientId: String? = null,
    val styleId: String? = null,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(
    tableName = "assignment",
    foreignKeys = [
        ForeignKey(entity = CutOrderEntity::class, parentColumns = ["id"], childColumns = ["orderId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = PlantEntity::class, parentColumns = ["id"], childColumns = ["plantId"], onDelete = ForeignKey.RESTRICT),
    ],
    indices = [Index("orderId"), Index("plantId")],
)
data class AssignmentEntity(
    @PrimaryKey val id: String = newId(),
    val orderId: String,
    val plantId: String?,
    val quantity: Long,
    val unitPrice: Double,
    val scheduledDate: Long?,
    @ColumnInfo(defaultValue = "en_espera") val cuttingStatus: String = "en_espera",
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(
    tableName = "production_report",
    foreignKeys = [
        ForeignKey(entity = AssignmentEntity::class, parentColumns = ["id"], childColumns = ["assignmentId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index("assignmentId")],
)
data class ReportEntity(
    @PrimaryKey val id: String = newId(),
    val assignmentId: String,
    val kind: String,
    val authorName: String? = null,
    val operators: Long = 0,
    val absences: Long = 0,
    val produced: Long = 0,
    val ironing: Long = 0,
    val packing: Long = 0,
    val warehouse: Long = 0,
    val cutStatus: String? = null,
    val realQuantity: Long = 0,
    val shipmentNumber: String? = null,
    val shippedQuantity: Long = 0,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(
    tableName = "project",
    foreignKeys = [
        ForeignKey(entity = ClientEntity::class, parentColumns = ["id"], childColumns = ["clientId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("clientId")],
)
data class ProjectEntity(
    @PrimaryKey val id: String = newId(),
    val clientName: String? = null,
    val clientId: String? = null,
    val quantity: Long = 0,
    val price: Double = 0.0,
    val minutes: Double = 0.0,
    val fabric: String? = null,
    @ColumnInfo(defaultValue = "pendiente") val status: String = "pendiente",
    val deliveryDate: Long? = null,
    val notes: String? = null,
    val photoFile: String? = null,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)

@Entity(
    tableName = "app_user",
    foreignKeys = [
        ForeignKey(entity = PlantEntity::class, parentColumns = ["id"], childColumns = ["plantId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [Index("plantId"), Index(value = ["email"], unique = true)],
)
data class UserEntity(
    @PrimaryKey val id: String = newId(),
    val firstName: String,
    val lastName: String = "",
    /** Always stored lowercase. */
    val email: String,
    val phone: String = "",
    val role: String,
    val passwordHash: String?,
    val passwordSalt: String?,
    val isActive: Boolean = true,
    val avatarFile: String? = null,
    val plantId: String? = null,
    val remoteId: Long = 0,
    val createdAt: Long = now(),
    val updatedAt: Long = now(),
)
