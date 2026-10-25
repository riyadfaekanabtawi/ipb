package com.nevutech.trama

import android.app.Application
import android.content.Context
import com.nevutech.trama.core.data.CatalogService
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.ProductionService
import com.nevutech.trama.core.data.Session
import com.nevutech.trama.core.data.SettingsStore
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.TramaRepository
import com.nevutech.trama.designsystem.ToastCenter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Dispatchers

/** Manual dependency container; small enough that a DI framework would only add weight. */
class AppContainer(context: Context, val db: TramaDatabase = TramaDatabase.build(context)) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    val settings = SettingsStore(context)
    val images = ImageStore(context)
    val repository = TramaRepository(db, scope)
    val session = Session(db.dao(), settings)
    val toasts = ToastCenter()

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
    }
}

val Context.container: AppContainer get() = (applicationContext as TramaApplication).container
