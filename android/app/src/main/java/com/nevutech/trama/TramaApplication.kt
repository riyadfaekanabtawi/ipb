package com.nevutech.trama

import android.app.Application
import android.content.Context
import android.os.Build
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.nevutech.trama.app.SyncTriggers
import com.nevutech.trama.core.data.CatalogService
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.ProductionService
import com.nevutech.trama.core.data.Session
import com.nevutech.trama.core.data.SettingsStore
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.TramaRepository
import com.nevutech.trama.core.data.sync.KeystoreSecretBox
import com.nevutech.trama.core.data.sync.SyncEngine
import com.nevutech.trama.core.data.sync.SyncPrefs
import com.nevutech.trama.core.data.sync.TramaApi
import com.nevutech.trama.designsystem.ToastCenter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

/**
 * Manual dependency container; small enough that a DI framework would only add weight.
 * [cloud] = false (debug demo store) gives sync its own throwaway settings, so demo data can
 * never reach a real company.
 */
class AppContainer(context: Context, val db: TramaDatabase = TramaDatabase.build(context), cloud: Boolean = true) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val settings = SettingsStore(context)
    val images = ImageStore(context)
    val repository = TramaRepository(db, scope)
    val session = Session(db.dao(), settings)
    val toasts = ToastCenter()

    @Volatile private var apiBase: String = BuildConfig.API_BASE
    private val syncPrefs = if (cloud) SyncPrefs(context) else SyncPrefs(
        PreferenceDataStoreFactory.create(scope = scope) { File(context.cacheDir, "demo-sync-${UUID.randomUUID()}.preferences_pb") },
        KeystoreSecretBox("trama.sync.demo"),
    )
    val sync = SyncEngine(
        db = db, images = images, prefs = syncPrefs, api = TramaApi { apiBase }, settings = settings, scope = scope,
        deviceName = Build.MODEL ?: "Android", backupDir = File(context.filesDir, "backups"),
        notify = { message, error -> toasts.show(message, if (error) ToastCenter.Style.Error else ToastCenter.Style.Success) },
        autoSyncAfterWrites = cloud,
    )

    init {
        if (cloud && BuildConfig.DEBUG) scope.launch { syncPrefs.apiBaseOverride()?.let { apiBase = it } }
    }

    /** Debug only: point the app at another API (e.g. http://10.0.2.2:8787/api on the emulator). */
    fun setApiBase(url: String) {
        apiBase = url.trim()
        scope.launch { syncPrefs.setApiBaseOverride(url) }
    }

    /** Production writes stamped with the signed-in user's name. */
    fun production(): ProductionService = session.service(db)

    fun catalog(): CatalogService = CatalogService(db, images)
}

class TramaApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        val sync = container.sync
        SyncTriggers.watchConnectivity(this, sync)
        container.scope.launch {
            sync.prefs.account.map { it.connected }.distinctUntilChanged().collect { SyncTriggers.schedule(this@TramaApplication, it) }
        }
    }
}

val Context.container: AppContainer get() = (applicationContext as TramaApplication).container
