package com.nevutech.trama.core.data

import androidx.room.withTransaction

/**
 * Deletes every row in one transaction (children first, so RESTRICT foreign keys never fire)
 * and, unless [keepImages], every stored image. Port of iOS `PersistenceController.eraseAll()`.
 */
suspend fun eraseAllData(db: TramaDatabase, images: ImageStore, keepImages: Boolean = false) {
    db.withTransaction { clearTables(db) }
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
