package com.nevutech.trama.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.nevutech.trama.container
import com.nevutech.trama.core.data.sync.SyncEngine
import java.util.concurrent.TimeUnit

/** Background sync every 30 minutes while connected (WorkManager keeps it battery friendly). */
class SyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        applicationContext.container.sync.syncNow(manual = false)
        return Result.success()
    }
}

object SyncTriggers {
    private const val PERIODIC = "trama-sync"

    /** Periodic sync, only while the device is linked to the cloud. */
    fun schedule(context: Context, linked: Boolean) {
        runCatching {
            val work = WorkManager.getInstance(context)
            if (!linked) {
                work.cancelUniqueWork(PERIODIC)
                return
            }
            val request = PeriodicWorkRequestBuilder<SyncWorker>(30, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            work.enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }

    /** Syncs as soon as a network comes back. */
    fun watchConnectivity(context: Context, engine: SyncEngine) {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        runCatching {
            manager.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = engine.requestSync()
            })
        }
    }
}
