package com.nevutech.trama.core.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Upsert
import androidx.sqlite.db.SupportSQLiteDatabase
import com.nevutech.trama.core.data.sync.MIGRATION_1_2
import com.nevutech.trama.core.data.sync.OutboxEntity
import com.nevutech.trama.core.data.sync.SyncDao
import com.nevutech.trama.core.data.sync.SyncSql
import com.nevutech.trama.core.data.sync.SyncStateEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TramaDao {
    // Live streams feeding the in-memory graph (datasets are small: hundreds to low thousands of rows).
    @Query("SELECT * FROM plant ORDER BY name") fun plants(): Flow<List<PlantEntity>>
    @Query("SELECT * FROM client ORDER BY name") fun clients(): Flow<List<ClientEntity>>
    @Query("SELECT * FROM supplier ORDER BY name") fun suppliers(): Flow<List<SupplierEntity>>
    @Query("SELECT * FROM contact ORDER BY sortIndex") fun contacts(): Flow<List<ContactEntity>>
    @Query("SELECT * FROM style ORDER BY name") fun styles(): Flow<List<StyleEntity>>
    @Query("SELECT * FROM cut_order ORDER BY code") fun orders(): Flow<List<CutOrderEntity>>
    @Query("SELECT * FROM assignment ORDER BY createdAt") fun assignments(): Flow<List<AssignmentEntity>>
    @Query("SELECT * FROM production_report ORDER BY createdAt DESC") fun reports(): Flow<List<ReportEntity>>
    @Query("SELECT * FROM project ORDER BY createdAt DESC") fun projects(): Flow<List<ProjectEntity>>
    @Query("SELECT * FROM app_user ORDER BY firstName") fun users(): Flow<List<UserEntity>>

    // One-shot reads used by services inside transactions.
    @Query("SELECT * FROM plant WHERE id = :id") suspend fun plant(id: String): PlantEntity?
    @Query("SELECT * FROM cut_order WHERE id = :id") suspend fun order(id: String): CutOrderEntity?
    @Query("SELECT * FROM assignment WHERE id = :id") suspend fun assignment(id: String): AssignmentEntity?
    @Query("SELECT * FROM assignment WHERE orderId = :orderId") suspend fun assignmentsOfOrder(orderId: String): List<AssignmentEntity>
    @Query("SELECT * FROM assignment WHERE plantId = :plantId") suspend fun assignmentsOfPlant(plantId: String): List<AssignmentEntity>
    @Query("SELECT * FROM production_report WHERE assignmentId = :assignmentId") suspend fun reportsOf(assignmentId: String): List<ReportEntity>
    @Query("SELECT * FROM production_report WHERE id = :id") suspend fun report(id: String): ReportEntity?
    @Query("SELECT COUNT(*) FROM cut_order WHERE clientId = :clientId") suspend fun orderCountOfClient(clientId: String): Int
    @Query("SELECT * FROM app_user WHERE email = :email COLLATE NOCASE LIMIT 1") suspend fun userByEmail(email: String): UserEntity?
    @Query("SELECT * FROM app_user WHERE id = :id") suspend fun user(id: String): UserEntity?
    @Query("SELECT * FROM app_user") suspend fun allUsers(): List<UserEntity>
    @Query("SELECT COUNT(*) FROM app_user") suspend fun userCount(): Int
    @Query("SELECT COUNT(*) FROM app_user") fun userCountFlow(): Flow<Int>

    @Upsert suspend fun upsert(plant: PlantEntity)
    @Upsert suspend fun upsert(client: ClientEntity)
    @Upsert suspend fun upsert(supplier: SupplierEntity)
    @Upsert suspend fun upsert(contact: ContactEntity)
    @Upsert suspend fun upsert(style: StyleEntity)
    @Upsert suspend fun upsert(order: CutOrderEntity)
    @Upsert suspend fun upsert(assignment: AssignmentEntity)
    @Upsert suspend fun upsert(report: ReportEntity)
    @Upsert suspend fun upsert(project: ProjectEntity)
    @Upsert suspend fun upsert(user: UserEntity)

    @Insert(onConflict = OnConflictStrategy.ABORT) suspend fun insertUser(user: UserEntity)

    @Delete suspend fun delete(plant: PlantEntity)
    @Delete suspend fun delete(client: ClientEntity)
    @Delete suspend fun delete(supplier: SupplierEntity)
    @Delete suspend fun delete(style: StyleEntity)
    @Delete suspend fun delete(order: CutOrderEntity)
    @Delete suspend fun delete(assignment: AssignmentEntity)
    @Delete suspend fun delete(report: ReportEntity)
    @Delete suspend fun delete(project: ProjectEntity)
    @Delete suspend fun delete(user: UserEntity)
    @Query("DELETE FROM contact WHERE clientId = :clientId") suspend fun deleteContactsOfClient(clientId: String)
    @Query("DELETE FROM contact WHERE supplierId = :supplierId") suspend fun deleteContactsOfSupplier(supplierId: String)
}

@Database(
    entities = [
        PlantEntity::class, ClientEntity::class, SupplierEntity::class, ContactEntity::class, StyleEntity::class,
        CutOrderEntity::class, AssignmentEntity::class, ReportEntity::class, ProjectEntity::class, UserEntity::class,
        OutboxEntity::class, SyncStateEntity::class,
    ],
    version = 2,
    exportSchema = true,
)
abstract class TramaDatabase : RoomDatabase() {
    abstract fun dao(): TramaDao
    abstract fun syncDao(): SyncDao

    companion object {
        /** Installs the sync triggers and state row on every open (idempotent; also covers fresh installs). */
        val syncCallback = object : Callback() {
            override fun onOpen(db: SupportSQLiteDatabase) = SyncSql.install(db)
        }

        fun build(context: Context): TramaDatabase =
            Room.databaseBuilder(context, TramaDatabase::class.java, "trama.db")
                .addMigrations(MIGRATION_1_2)
                .addCallback(syncCallback)
                .build()

        fun inMemory(context: Context): TramaDatabase =
            Room.inMemoryDatabaseBuilder(context, TramaDatabase::class.java).allowMainThreadQueries().addCallback(syncCallback).build()
    }
}
