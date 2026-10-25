package com.nevutech.trama.core.data.sync

import android.database.sqlite.SQLiteConstraintException
import androidx.room.withTransaction
import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.UserEntity
import com.nevutech.trama.core.data.eraseAllData
import com.nevutech.trama.core.data.now
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * The database side of sync: applies server changes (no network here, so it is unit tested
 * directly), builds push payloads from the outbox, and handles linking resets.
 */
class SyncStore(private val db: TramaDatabase, private val images: ImageStore) {
    private val dao = db.dao()
    private val sync = db.syncDao()

    data class ApplyResult(val applied: Int = 0, val deleted: Int = 0, val skipped: Int = 0)

    /** Runs [block] in a transaction with the outbox triggers (and the read-only guard) switched off. */
    suspend fun <T> suppressed(block: suspend () -> T): T = db.withTransaction {
        sync.setApplying(true)
        try { block() } finally { sync.setApplying(false) }
    }

    suspend fun cursor(): Long = sync.state()?.cursor ?: 0

    suspend fun setReadOnly(readOnly: Boolean) {
        if (sync.state()?.readOnly != readOnly) sync.setReadOnly(readOnly)
    }

    /**
     * Applies pulled changes by id: upsert, or delete for tombstones. Last writer wins: a change is
     * skipped while this device holds a newer unpushed edit of the same row (it will be pushed
     * instead); otherwise the server copy replaces the local row and any older local edit is dropped.
     * [force] adopts the server copy unconditionally (stale push rejections). Parents are applied
     * before children and deletes run children-first, so foreign keys hold whatever the page order.
     * [cursor] is saved in the same transaction.
     */
    suspend fun apply(changes: List<ServerChange>, force: Boolean = false, cursor: Long? = null): ApplyResult {
        val latest = LinkedHashMap<Pair<String, String>, ServerChange>()
        for (change in changes) {
            val id = SyncCodec.localId(change.id) ?: continue
            if (SyncTables.ofEntity(change.entity) == null) continue
            val key = change.entity to id
            val previous = latest[key]
            if (previous == null || change.version >= previous.version) latest[key] = change.copy(id = id)
        }
        val deletes = latest.values.filter { it.deleted || it.data == null }.sortedByDescending { SyncTables.rank(it.entity) }
        val upserts = latest.values.filter { !it.deleted && it.data != null }.sortedBy { SyncTables.rank(it.entity) }

        val written = mutableListOf<String>()
        val replaced = mutableListOf<String>()
        var applied = 0
        var deleted = 0
        var skipped = 0
        try {
            suppressed {
                for (change in deletes + upserts) {
                    if (!force && localWins(change)) { skipped++; continue }
                    val ok = if (change.deleted || change.data == null) delete(change, replaced) else upsert(change, change.data, written, replaced)
                    sync.drop(change.entity, change.id)
                    if (ok) { if (change.deleted || change.data == null) deleted++ else applied++ } else skipped++
                }
                cursor?.let { sync.setCursor(it) }
            }
        } catch (e: Throwable) {
            written.forEach(images::delete)
            throw e
        }
        replaced.distinct().forEach(images::delete)
        return ApplyResult(applied, deleted, skipped)
    }

    private suspend fun localWins(change: ServerChange): Boolean {
        val pending = sync.pending(change.entity, change.id) ?: return false
        val remote = runCatching { BackupService.parseDate(change.updatedAt) }.getOrDefault(0L)
        return pending.changedAt > remote
    }

    private suspend fun delete(change: ServerChange, replaced: MutableList<String>): Boolean {
        val id = change.id
        return try {
            when (SyncTables.ofEntity(change.entity)) {
                SyncTables.Plants -> sync.deletePlant(id)
                SyncTables.Clients -> sync.deleteClient(id)
                SyncTables.Suppliers -> sync.deleteSupplier(id)
                SyncTables.Contacts -> sync.deleteContact(id)
                SyncTables.Styles -> { sync.style(id)?.imageFile?.let(replaced::add); sync.deleteStyle(id) }
                SyncTables.Orders -> sync.deleteOrder(id)
                SyncTables.Assignments -> sync.deleteAssignment(id)
                SyncTables.Reports -> sync.deleteReport(id)
                SyncTables.Projects -> { sync.project(id)?.photoFile?.let(replaced::add); sync.deleteProject(id) }
                SyncTables.Users -> { sync.user(id)?.avatarFile?.let(replaced::add); sync.deleteUser(id) }
                null -> return false
            }
            true
        } catch (e: SQLiteConstraintException) {
            // A RESTRICT parent (plant/client) still has local children the server didn't delete.
            false
        }
    }

    private suspend fun upsert(change: ServerChange, data: JsonObject, written: MutableList<String>, replaced: MutableList<String>): Boolean {
        val id = change.id
        val stamp = now()
        fun image(current: String?, bytes: ByteArray?): String? {
            if (bytes == null) { current?.let(replaced::add); return null }
            if (current != null && images.read(current)?.contentEquals(bytes) == true) return current
            current?.let(replaced::add)
            return images.saveRaw(bytes).also(written::add)
        }
        suspend fun plantRef(raw: String?) = raw?.takeIf { sync.plant(it) != null }
        suspend fun clientRef(raw: String?) = raw?.takeIf { sync.client(it) != null }

        when (SyncTables.ofEntity(change.entity)) {
            SyncTables.Plants -> dao.upsert(SyncCodec.plant(id, data, stamp))
            SyncTables.Clients -> dao.upsert(SyncCodec.client(id, data, stamp))
            SyncTables.Suppliers -> dao.upsert(SyncCodec.supplier(id, data, stamp))
            SyncTables.Contacts -> SyncCodec.contact(id, data).let {
                dao.upsert(it.copy(clientId = clientRef(it.clientId), supplierId = it.supplierId?.takeIf { s -> sync.supplier(s) != null }))
            }
            SyncTables.Styles -> SyncCodec.style(id, data, stamp).let { (row, bytes) ->
                dao.upsert(row.copy(imageFile = image(sync.style(id)?.imageFile, bytes)))
            }
            SyncTables.Orders -> SyncCodec.order(id, data, stamp).let {
                dao.upsert(it.copy(clientId = clientRef(it.clientId), styleId = it.styleId?.takeIf { s -> sync.style(s) != null }))
            }
            SyncTables.Assignments -> {
                val row = SyncCodec.assignment(id, data, stamp)?.takeIf { sync.order(it.orderId) != null } ?: return false
                dao.upsert(row.copy(plantId = plantRef(row.plantId)))
            }
            SyncTables.Reports -> {
                val row = SyncCodec.report(id, data, stamp)?.takeIf { sync.assignment(it.assignmentId) != null } ?: return false
                dao.upsert(row)
            }
            SyncTables.Projects -> SyncCodec.project(id, data, stamp).let { (row, bytes) ->
                dao.upsert(row.copy(clientId = clientRef(row.clientId), photoFile = image(sync.project(id)?.photoFile, bytes)))
            }
            SyncTables.Users -> {
                val (row, bytes) = SyncCodec.user(id, data, stamp) ?: return false
                // Emails are unique: a different local user with the same email yields to the server's.
                sync.userByEmail(row.email)?.takeIf { it.id != id }?.let { other ->
                    other.avatarFile?.let(replaced::add)
                    sync.deleteUser(other.id)
                }
                val current = sync.user(id)
                dao.upsert(
                    row.copy(
                        plantId = plantRef(row.plantId),
                        // The server omits hashes in some responses; never wipe a working offline password.
                        passwordHash = row.passwordHash ?: current?.passwordHash,
                        passwordSalt = row.passwordSalt ?: current?.passwordSalt,
                        avatarFile = image(current?.avatarFile, bytes),
                    ),
                )
            }
            null -> return false
        }
        return true
    }

    /** Upserts the signed-in user from a login/refresh response and returns the local row. */
    suspend fun adoptUser(data: JsonObject): UserEntity? {
        val id = SyncCodec.localId((data["id"] as? JsonPrimitive)?.content) ?: return null
        val updatedAt = (data["updatedAt"] as? JsonPrimitive)?.content ?: BackupService.formatDate(now())
        apply(listOf(ServerChange("users", id, updatedAt, false, data)), force = true)
        return sync.user(id)
    }

    // Push

    /** Outbox rows in push order: upserts parents-first, then deletes children-first. */
    suspend fun pending(): List<OutboxEntity> {
        val rows = sync.outbox()
        return rows.filter { !it.deleted }.sortedWith(compareBy({ SyncTables.rank(it.entity) }, { it.changedAt })) +
            rows.filter { it.deleted }.sortedWith(compareByDescending<OutboxEntity> { SyncTables.rank(it.entity) }.thenBy { it.changedAt })
    }

    /** The wire change for an outbox row (a vanished row is sent as a delete). */
    suspend fun change(row: OutboxEntity): PushChange {
        val id = row.id
        val data: Pair<JsonObject, Long>? = if (row.deleted) null else when (SyncTables.ofEntity(row.entity)) {
            SyncTables.Plants -> sync.plant(id)?.let { SyncCodec.encode(it) to it.updatedAt }
            SyncTables.Clients -> sync.client(id)?.let { SyncCodec.encode(it) to it.updatedAt }
            SyncTables.Suppliers -> sync.supplier(id)?.let { SyncCodec.encode(it) to it.updatedAt }
            SyncTables.Contacts -> sync.contact(id)?.let { SyncCodec.encode(it) to 0L }
            SyncTables.Styles -> sync.style(id)?.let { SyncCodec.encode(it, images.read(it.imageFile)) to it.updatedAt }
            SyncTables.Orders -> sync.order(id)?.let { SyncCodec.encode(it) to it.updatedAt }
            SyncTables.Assignments -> sync.assignment(id)?.let { SyncCodec.encode(it) to it.updatedAt }
            SyncTables.Reports -> sync.report(id)?.let { SyncCodec.encode(it) to it.updatedAt }
            SyncTables.Projects -> sync.project(id)?.let { SyncCodec.encode(it, images.read(it.photoFile)) to it.updatedAt }
            SyncTables.Users -> sync.user(id)?.let { SyncCodec.encode(it, images.read(it.avatarFile)) to it.updatedAt }
            null -> null
        }
        val updatedAt = maxOf(row.changedAt, data?.second ?: 0L)
        return PushChange(row.entity, SyncCodec.wireId(id), BackupService.formatDate(updatedAt), deleted = data == null, data = data?.first)
    }

    suspend fun ack(row: OutboxEntity) = sync.ack(row.entity, row.id, row.rev)

    // Linking

    suspend fun hasLocalData(): Boolean = SyncTables.entries.any { t ->
        db.query("SELECT 1 FROM `${t.table}` LIMIT 1", null).use { it.moveToFirst() }
    }

    /** Queues every local row for upload (first link of a device to an empty company), except users with [skipEmails]. */
    suspend fun enqueueAll(skipEmails: Set<String>) = db.withTransaction {
        val sql = db.openHelper.writableDatabase
        val stamp = now()
        sql.execSQL("DELETE FROM sync_outbox")
        SyncTables.entries.forEach { t ->
            sql.execSQL("INSERT OR REPLACE INTO sync_outbox (entity, id, deleted, changedAt, rev) SELECT '${t.entity}', id, 0, $stamp, 1 FROM `${t.table}`")
        }
        dao.allUsers().filter { it.email.lowercase() in skipEmails }.forEach { sync.drop(SyncTables.Users.entity, it.id) }
    }

    /** Local reset before adopting a company's data: rows and images go, nothing is queued, the cursor restarts. */
    suspend fun eraseLocal() = eraseAllData(db, images)

    suspend fun resetLink() = db.withTransaction {
        sync.clearOutbox()
        sync.setCursor(0)
        sync.setReadOnly(false)
    }
}
