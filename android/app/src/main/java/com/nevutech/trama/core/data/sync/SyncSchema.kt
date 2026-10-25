package com.nevutech.trama.core.data.sync

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.nevutech.trama.core.data.AssignmentEntity
import com.nevutech.trama.core.data.ClientEntity
import com.nevutech.trama.core.data.ContactEntity
import com.nevutech.trama.core.data.CutOrderEntity
import com.nevutech.trama.core.data.PlantEntity
import com.nevutech.trama.core.data.ProjectEntity
import com.nevutech.trama.core.data.ReportEntity
import com.nevutech.trama.core.data.StyleEntity
import com.nevutech.trama.core.data.SupplierEntity
import com.nevutech.trama.core.data.UserEntity
import kotlinx.coroutines.flow.Flow

// Local bookkeeping for cloud sync (docs/DOMAIN.md, "Sync").
//
// Every write to a synced table is captured by SQLite triggers into `sync_outbox`, in the same
// transaction as the write itself. That covers every write path (services, cascades, direct DAO
// calls, backup restore) without each one having to remember to enqueue. Changes applied from
// the server run with `sync_state.applying = 1`, which silences the triggers.

/** One pending local change per row; repeated edits coalesce, `rev` detects edits made mid-push. */
@Entity(tableName = "sync_outbox", primaryKeys = ["entity", "id"])
data class OutboxEntity(
    /** Sync entity name (`plants`, `orders`, …), see [SyncTables]. */
    val entity: String,
    /** Local (lowercase) row id. */
    val id: String,
    val deleted: Boolean,
    /** Epoch millis of the latest local write. */
    val changedAt: Long,
    val rev: Long,
)

/** Single row (id = 1): trigger switch, read-only licence flag and the pull cursor. */
@Entity(tableName = "sync_state")
data class SyncStateEntity(
    @PrimaryKey val id: Int = 1,
    val applying: Boolean = false,
    val readOnly: Boolean = false,
    val cursor: Long = 0,
)

/** Synced tables in dependency order (parents first) with their protocol entity names. */
enum class SyncTables(val table: String, val entity: String) {
    Plants("plant", "plants"),
    Clients("client", "clients"),
    Suppliers("supplier", "suppliers"),
    Contacts("contact", "contacts"),
    Styles("style", "styles"),
    Orders("cut_order", "orders"),
    Assignments("assignment", "assignments"),
    Reports("production_report", "reports"),
    Projects("project", "projects"),
    Users("app_user", "users");

    companion object {
        fun ofEntity(entity: String): SyncTables? = entries.firstOrNull { it.entity == entity }
        fun rank(entity: String): Int = ofEntity(entity)?.ordinal ?: Int.MAX_VALUE
    }
}

/** Raised by the read-only triggers; mapped to Spanish copy in the UI. */
const val READ_ONLY_MARKER = "TRAMA_READ_ONLY"

object SyncSql {
    private const val NOW_MS = "CAST(ROUND((julianday('now') - 2440587.5) * 86400000) AS INTEGER)"
    private const val NOT_APPLYING = "IFNULL((SELECT applying FROM sync_state WHERE id = 1), 0) = 0"
    private const val READ_ONLY = "IFNULL((SELECT readOnly FROM sync_state WHERE id = 1), 0) = 1"

    private fun enqueue(entity: String, ref: String, deleted: Int) =
        "INSERT OR REPLACE INTO sync_outbox (entity, id, deleted, changedAt, rev) VALUES ('$entity', $ref.id, $deleted, $NOW_MS, " +
            "IFNULL((SELECT rev FROM sync_outbox WHERE entity = '$entity' AND id = $ref.id), 0) + 1);"

    /** Idempotent: safe to run on every open. */
    val triggers: List<String> = SyncTables.entries.flatMap { t ->
        val n = t.table
        listOf(
            "CREATE TRIGGER IF NOT EXISTS sync_${n}_ins AFTER INSERT ON `$n` WHEN $NOT_APPLYING BEGIN ${enqueue(t.entity, "NEW", 0)} END",
            "CREATE TRIGGER IF NOT EXISTS sync_${n}_upd AFTER UPDATE ON `$n` WHEN $NOT_APPLYING BEGIN ${enqueue(t.entity, "NEW", 0)} END",
            "CREATE TRIGGER IF NOT EXISTS sync_${n}_del AFTER DELETE ON `$n` WHEN $NOT_APPLYING BEGIN ${enqueue(t.entity, "OLD", 1)} END",
        ) + listOf("INSERT", "UPDATE", "DELETE").map { op ->
            "CREATE TRIGGER IF NOT EXISTS ro_${n}_${op.lowercase()} BEFORE $op ON `$n` WHEN $READ_ONLY AND $NOT_APPLYING " +
                "BEGIN SELECT RAISE(ABORT, '$READ_ONLY_MARKER'); END"
        }
    }

    fun install(db: SupportSQLiteDatabase) {
        db.execSQL("INSERT OR IGNORE INTO sync_state (id, applying, readOnly, cursor) VALUES (1, 0, 0, 0)")
        // A crash can't leave the switch on (it is only set inside transactions), but be defensive.
        db.execSQL("UPDATE sync_state SET applying = 0 WHERE id = 1")
        triggers.forEach(db::execSQL)
    }
}

/** v1 → v2: adds the outbox and sync state. Existing rows are not enqueued (see SyncEngine linking). */
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS `sync_outbox` (`entity` TEXT NOT NULL, `id` TEXT NOT NULL, `deleted` INTEGER NOT NULL, " +
                "`changedAt` INTEGER NOT NULL, `rev` INTEGER NOT NULL, PRIMARY KEY(`entity`, `id`))",
        )
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS `sync_state` (`id` INTEGER NOT NULL, `applying` INTEGER NOT NULL, `readOnly` INTEGER NOT NULL, " +
                "`cursor` INTEGER NOT NULL, PRIMARY KEY(`id`))",
        )
        SyncSql.install(db)
    }
}

@Dao
interface SyncDao {
    @Query("SELECT * FROM sync_outbox") suspend fun outbox(): List<OutboxEntity>
    @Query("SELECT * FROM sync_outbox WHERE entity = :entity AND id = :id") suspend fun pending(entity: String, id: String): OutboxEntity?
    @Query("SELECT COUNT(*) FROM sync_outbox") fun pendingCount(): Flow<Int>
    @Query("DELETE FROM sync_outbox WHERE entity = :entity AND id = :id AND rev = :rev") suspend fun ack(entity: String, id: String, rev: Long)
    @Query("DELETE FROM sync_outbox WHERE entity = :entity AND id = :id") suspend fun drop(entity: String, id: String)
    @Query("DELETE FROM sync_outbox") suspend fun clearOutbox()

    @Query("SELECT * FROM sync_state WHERE id = 1") suspend fun state(): SyncStateEntity?
    @Query("SELECT readOnly FROM sync_state WHERE id = 1") fun readOnlyFlow(): Flow<Boolean?>
    @Query("UPDATE sync_state SET applying = :on WHERE id = 1") suspend fun setApplying(on: Boolean)
    @Query("UPDATE sync_state SET readOnly = :on WHERE id = 1") suspend fun setReadOnly(on: Boolean)
    @Query("UPDATE sync_state SET cursor = :cursor WHERE id = 1") suspend fun setCursor(cursor: Long)

    // One-shot reads by id (push payloads, conflict checks).
    @Query("SELECT * FROM plant WHERE id = :id") suspend fun plant(id: String): PlantEntity?
    @Query("SELECT * FROM client WHERE id = :id") suspend fun client(id: String): ClientEntity?
    @Query("SELECT * FROM supplier WHERE id = :id") suspend fun supplier(id: String): SupplierEntity?
    @Query("SELECT * FROM contact WHERE id = :id") suspend fun contact(id: String): ContactEntity?
    @Query("SELECT * FROM style WHERE id = :id") suspend fun style(id: String): StyleEntity?
    @Query("SELECT * FROM cut_order WHERE id = :id") suspend fun order(id: String): CutOrderEntity?
    @Query("SELECT * FROM assignment WHERE id = :id") suspend fun assignment(id: String): AssignmentEntity?
    @Query("SELECT * FROM production_report WHERE id = :id") suspend fun report(id: String): ReportEntity?
    @Query("SELECT * FROM project WHERE id = :id") suspend fun project(id: String): ProjectEntity?
    @Query("SELECT * FROM app_user WHERE id = :id") suspend fun user(id: String): UserEntity?
    @Query("SELECT * FROM app_user WHERE email = :email COLLATE NOCASE LIMIT 1") suspend fun userByEmail(email: String): UserEntity?

    @Query("SELECT id FROM plant") suspend fun plantIds(): List<String>
    @Query("SELECT id FROM client") suspend fun clientIds(): List<String>
    @Query("SELECT id FROM supplier") suspend fun supplierIds(): List<String>
    @Query("SELECT id FROM contact") suspend fun contactIds(): List<String>
    @Query("SELECT id FROM style") suspend fun styleIds(): List<String>
    @Query("SELECT id FROM cut_order") suspend fun orderIds(): List<String>
    @Query("SELECT id FROM assignment") suspend fun assignmentIds(): List<String>
    @Query("SELECT id FROM production_report") suspend fun reportIds(): List<String>
    @Query("SELECT id FROM project") suspend fun projectIds(): List<String>
    @Query("SELECT id FROM app_user") suspend fun userIds(): List<String>

    @Query("DELETE FROM plant WHERE id = :id") suspend fun deletePlant(id: String)
    @Query("DELETE FROM client WHERE id = :id") suspend fun deleteClient(id: String)
    @Query("DELETE FROM supplier WHERE id = :id") suspend fun deleteSupplier(id: String)
    @Query("DELETE FROM contact WHERE id = :id") suspend fun deleteContact(id: String)
    @Query("DELETE FROM style WHERE id = :id") suspend fun deleteStyle(id: String)
    @Query("DELETE FROM cut_order WHERE id = :id") suspend fun deleteOrder(id: String)
    @Query("DELETE FROM assignment WHERE id = :id") suspend fun deleteAssignment(id: String)
    @Query("DELETE FROM production_report WHERE id = :id") suspend fun deleteReport(id: String)
    @Query("DELETE FROM project WHERE id = :id") suspend fun deleteProject(id: String)
    @Query("DELETE FROM app_user WHERE id = :id") suspend fun deleteUser(id: String)
}
