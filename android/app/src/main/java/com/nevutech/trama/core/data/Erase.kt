package com.nevutech.trama.core.data

import androidx.room.withTransaction

/**
 * Deletes every row in one transaction (children first, so RESTRICT foreign keys never fire)
 * and, unless [keepImages], every stored image. Port of iOS `PersistenceController.eraseAll()`.
 * A local reset: nothing is queued for sync, and the outbox and pull cursor start over.
 */
suspend fun eraseAllData(db: TramaDatabase, images: ImageStore, keepImages: Boolean = false) {
    val sync = db.syncDao()
    db.withTransaction {
        sync.setApplying(true)
        clearTables(db)
        sync.setApplying(false)
        sync.clearOutbox()
        sync.setCursor(0)
    }
    if (!keepImages) images.clear()
}

/** Must run inside a Room transaction. */
internal fun clearTables(db: TramaDatabase) {
    val sql = db.openHelper.writableDatabase
    ERASE_ORDER.forEach { sql.execSQL("DELETE FROM `$it`") }
}

/** Reverse of the restore order: dependents before the rows they reference. */
private val ERASE_ORDER = listOf(
    "app_user", "project", "production_report", "assignment", "cut_order", "style", "contact", "supplier", "client", "plant",
)
