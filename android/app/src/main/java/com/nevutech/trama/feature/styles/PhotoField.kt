package com.nevutech.trama.feature.styles

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import coil3.compose.AsyncImage
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.core.data.ImageEdit
import com.nevutech.trama.core.data.newId
import com.nevutech.trama.designsystem.Swatch
import com.nevutech.trama.designsystem.ToastCenter
import com.nevutech.trama.designsystem.Tokens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** True when the slot will show a picture after saving. */
fun ImageEdit.hasImage(currentFile: File?) = when (this) {
    ImageEdit.Keep -> currentFile != null
    ImageEdit.Remove -> false
    is ImageEdit.Replace -> true
}

/** Preview of an image slot: the picked bytes, the stored file, or the woven placeholder. */
@Composable
fun PhotoPreview(title: String, currentFile: File?, edit: ImageEdit, modifier: Modifier = Modifier, corner: Dp = 14.dp) {
    when (edit) {
        is ImageEdit.Replace -> AsyncImage(edit.bytes, title, modifier.clip(RoundedCornerShape(corner)), contentScale = ContentScale.Crop)
        ImageEdit.Remove -> Swatch(title, null, modifier, corner)
        ImageEdit.Keep -> Swatch(title, currentFile, modifier, corner)
    }
}

/**
 * Photo slot with preview plus "Elegir de fotos" (system photo picker), "Tomar foto" (camera into
 * a FileProvider uri under cache/camera) and "Quitar". The result is an [ImageEdit] that
 * CatalogService turns into a file through ImageStore.
 */
@Composable
fun PhotoField(title: String, currentFile: File?, edit: ImageEdit, onChange: (ImageEdit) -> Unit) {
    val context = LocalContext.current
    val toasts = LocalApp.current.toasts
    val scope = rememberCoroutineScope()
    val hasCamera = remember { context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) }
    var pendingCapture by rememberSaveable { mutableStateOf<String?>(null) }

    fun load(read: suspend () -> ByteArray?) = scope.launch {
        val bytes = withContext(Dispatchers.IO) { runCatching { read() }.getOrNull() }
        if (bytes != null && bytes.isNotEmpty()) onChange(ImageEdit.Replace(bytes))
        else toasts.show("No se pudo leer la imagen.", ToastCenter.Style.Error)
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri != null) load { context.contentResolver.openInputStream(uri)?.use { it.readBytes() } }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val file = pendingCapture?.let(::File)
        pendingCapture = null
        if (saved && file != null) load { file.readBytes().also { file.delete() } } else file?.delete()
    }

    Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
        PhotoPreview(title, currentFile, edit, Modifier.size(84.dp))
        Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
            val has = edit.hasImage(currentFile)
            TextButton({ picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) {
                Icon(Icons.Filled.PhotoLibrary, null, Modifier.size(18.dp))
                Text(if (has) "  Cambiar foto" else "  Elegir de fotos")
            }
            if (hasCamera) {
                TextButton({
                    runCatching { captureTarget(context) }
                        .onSuccess { (file, uri) -> pendingCapture = file.absolutePath; camera.launch(uri) }
                        .onFailure { toasts.show("No se pudo abrir la cámara.", ToastCenter.Style.Error) }
                }) {
                    Icon(Icons.Filled.PhotoCamera, null, Modifier.size(18.dp))
                    Text("  Tomar foto")
                }
            }
            if (has) {
                TextButton({ onChange(ImageEdit.Remove) }) {
                    Icon(Icons.Filled.Delete, null, Modifier.size(18.dp), tint = Tokens.colors.danger)
                    Text("  Quitar", color = Tokens.colors.danger)
                }
            }
        }
    }
}

private fun captureTarget(context: Context): Pair<File, Uri> {
    val dir = File(context.cacheDir, "camera").apply { mkdirs() }
    val file = File(dir, "capture-${newId()}.jpg")
    return file to FileProvider.getUriForFile(context, "${context.packageName}.files", file)
}
