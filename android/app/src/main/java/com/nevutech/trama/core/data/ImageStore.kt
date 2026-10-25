package com.nevutech.trama.core.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Images (styles, projects, avatars) live as JPEG files in filesDir/images; Room only stores the
 * file name. Keeps rows small (Android's CursorWindow caps a row at ~2 MB).
 */
class ImageStore(context: Context) {
    private val dir = File(context.filesDir, "images").apply { mkdirs() }

    fun file(name: String?): File? = name?.let { File(dir, it) }?.takeIf { it.exists() }

    /** Downscales to [maxDimension] and stores as JPEG; returns the new file name. */
    fun save(bytes: ByteArray, maxDimension: Int = 1600): String {
        val compressed = compress(bytes, maxDimension) ?: bytes
        val name = "${newId()}.jpg"
        File(dir, name).writeBytes(compressed)
        return name
    }

    fun save(context: Context, uri: Uri): String? =
        context.contentResolver.openInputStream(uri)?.use { save(it.readBytes()) }

    fun read(name: String?): ByteArray? = file(name)?.readBytes()

    fun delete(name: String?) {
        file(name)?.delete()
    }

    fun clear() {
        dir.listFiles()?.forEach { it.delete() }
    }

    private fun compress(bytes: ByteArray, maxDimension: Int): ByteArray? {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val longest = maxOf(bitmap.width, bitmap.height)
        val scaled = if (longest > maxDimension) {
            val scale = maxDimension.toFloat() / longest
            Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
        } else bitmap
        return ByteArrayOutputStream().use { out ->
            scaled.compress(Bitmap.CompressFormat.JPEG, 72, out)
            out.toByteArray()
        }
    }
}
