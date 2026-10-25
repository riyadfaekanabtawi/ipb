package com.nevutech.trama.core.data.sync

import com.nevutech.trama.core.data.BackupService
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.SettingsStore
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.UserEntity
import com.nevutech.trama.core.data.now
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.JsonPrimitive
import java.io.File
import java.time.LocalDate

/** Everything the UI shows about sync. */
data class SyncStatus(
    val account: CloudAccount = CloudAccount(),
    val pending: Int = 0,
    val running: Boolean = false,
) {
    val connected: Boolean get() = account.connected
    /** Writes are blocked while the company's licence is expired or suspended. */
    val readOnly: Boolean get() = account.connected && !account.writable
}

/**
 * Offline-first sync with the Trama platform (platform/src/sync.ts). Room stays the source of
 * truth: the app works the same with no network, and sync is a best-effort background job.
 *
 * - push: the outbox (filled by triggers, see SyncSchema) is sent in batches; applied rows are
 *   acknowledged, stale rejections adopt the server copy, other rejections are reported.
 * - pull: pages after the persisted cursor are collected and applied in one transaction
 *   (upsert by id, tombstones delete, last writer wins; see [SyncStore.apply]).
 * - auth: login stores the rotating refresh token sealed by the Keystore; the 15-minute access
 *   token lives in memory and is refreshed on a 401.
 */
@OptIn(FlowPreview::class)
class SyncEngine(
    private val db: TramaDatabase,
    private val images: ImageStore,
    val prefs: SyncPrefs,
    private val api: TramaApi,
    private val settings: SettingsStore,
    private val scope: CoroutineScope,
    private val deviceName: String,
    private val backupDir: File? = null,
    /** User-facing messages (Spanish); `true` marks an error. */
    private val notify: (String, Boolean) -> Unit = { _, _ -> },
    autoSyncAfterWrites: Boolean = true,
) {
    val store = SyncStore(db, images)
    private val mutex = Mutex()
    private val running = MutableStateFlow(false)
    @Volatile private var accessToken: String? = null
    @Volatile private var rerun = false

    val status: StateFlow<SyncStatus> =
        combine(prefs.account, db.syncDao().pendingCount(), running) { account, pending, busy -> SyncStatus(account, pending, busy) }
            .stateIn(scope, SharingStarted.Eagerly, SyncStatus())

    init {
        if (autoSyncAfterWrites) {
            // Local writes land in the outbox; push them a few seconds after the last one.
            scope.launch {
                db.syncDao().pendingCount().drop(1).debounce(WRITE_DEBOUNCE_MS).filter { it > 0 }.collect { requestSync() }
            }
        }
    }

    /** Fire-and-forget sync (app start/resume, connectivity regained, after writes, periodic). */
    fun requestSync() {
        if (mutex.isLocked) { rerun = true; return }
        scope.launch {
            syncNow(manual = false)
            if (rerun) { rerun = false; syncNow(manual = false) }
        }
    }

    /** Push then pull. Returns whether it completed; failures are recorded in the status. */
    suspend fun syncNow(manual: Boolean = true): Boolean {
        if (!prefs.account().connected) {
            if (manual) notify("Conecta tu licencia para sincronizar.", true)
            return false
        }
        return mutex.withLock {
            running.value = true
            try {
                val blocked = push()
                pull()
                prefs.recordSync(now(), blocked)
                if (blocked != null) {
                    if (manual) notify(blocked, true)
                    false
                } else {
                    if (manual) notify("Sincronizado", false)
                    true
                }
            } catch (e: OfflineException) {
                prefs.recordSync(null, e.message)
                if (manual) notify(e.message ?: "", true)
                false
            } catch (e: ApiException) {
                prefs.recordSync(null, e.message)
                if (manual || e.status == 401 || e.status == 402) notify(e.message ?: "", true)
                false
            } finally {
                running.value = false
            }
        }
    }

    // Sign in / out

    /**
     * "Conectar con mi licencia": signs in to the cloud, links this device to the company, syncs,
     * and returns the local user (with its password hash, so later sign-ins work offline).
     */
    suspend fun signIn(email: String, password: String): UserEntity = mutex.withLock {
        running.value = true
        try {
            val cleanEmail = email.trim().lowercase()
            if (cleanEmail.isEmpty() || password.isEmpty()) throw ApiException(422, "empty", "Escribe tu correo y tu contraseña.")
            val auth = api.login(cleanEmail, password, DeviceInfo(prefs.deviceId(), "android", deviceName))
            accessToken = auth.accessToken
            if (prefs.account().tenantId != auth.tenant.id) link(auth)
            prefs.setRefreshToken(auth.refreshToken)
            prefs.saveLink(auth.tenant, cleanEmail)
            applyLicence(auth.licence)
            settings.setCompanyName(auth.tenant.name)
            try {
                push()
                pull()
                prefs.recordSync(now(), null)
            } catch (e: Exception) {
                // Signed in anyway: the next sync retries.
                prefs.recordSync(null, e.message)
            }
            store.adoptUser(auth.user) ?: throw ApiException(500, "bad_response", "Respuesta inesperada del servidor. Intenta más tarde.")
        } finally {
            running.value = false
        }
    }

    /**
     * First sign-in of this device to a company. An empty company is seeded with this device's
     * data (an existing tablet going online); otherwise the company's data replaces the local
     * data, after an automatic backup file so nothing is lost. Demo data is never uploaded.
     */
    private suspend fun link(auth: AuthResponse) {
        val probe = api.pull(auth.accessToken, 0, 200)
        val serverHasData = probe.hasMore || probe.changes.any { it.entity != SyncTables.Users.entity && !it.deleted }
        val demo = settings.demoSeeded.first()
        store.resetLink()
        if (!serverHasData && !demo) {
            val serverEmails = probe.changes.filter { it.entity == SyncTables.Users.entity }
                .mapNotNull { (it.data?.get("email") as? JsonPrimitive)?.content?.lowercase() }.toSet() +
                ((auth.user["email"] as? JsonPrimitive)?.content?.lowercase() ?: "")
            store.enqueueAll(serverEmails)
        } else {
            if (!demo && store.hasLocalData()) autoBackup()
            store.eraseLocal()
            settings.setDemoSeeded(false)
        }
    }

    private suspend fun autoBackup() {
        val dir = backupDir ?: return
        runCatching {
            dir.mkdirs()
            File(dir, "Trama-respaldo-antes-de-vincular-${LocalDate.now()}-${now()}.json").writeBytes(BackupService.export(db, images))
        }
    }

    /** Signs this device out of the cloud and frees its seat. Local data stays. */
    suspend fun signOutCloud() = mutex.withLock {
        runCatching {
            val token = accessToken ?: refreshAccess()
            api.logout(token)
        }
        accessToken = null
        prefs.setRefreshToken(null)
        store.setReadOnly(false)
    }

    /** Forgets the company link (used by "Borrar todos los datos"). */
    suspend fun forget() {
        signOutCloud()
        prefs.forgetLink()
        store.resetLink()
    }

    // Protocol

    private suspend fun <T> withAuth(block: suspend (String) -> T): T {
        val token = accessToken ?: refreshAccess()
        return try {
            block(token)
        } catch (e: ApiException) {
            if (e.status != 401) throw e
            block(refreshAccess())
        }
    }

    private suspend fun refreshAccess(): String {
        val refresh = prefs.refreshToken() ?: throw sessionExpired()
        val auth = try {
            api.refresh(refresh)
        } catch (e: ApiException) {
            if (e.status == 401) {
                accessToken = null
                prefs.setRefreshToken(null)
                throw sessionExpired()
            }
            throw e
        }
        prefs.setRefreshToken(auth.refreshToken)
        accessToken = auth.accessToken
        applyLicence(auth.licence)
        return auth.accessToken
    }

    private fun sessionExpired() = ApiException(401, "session_expired", "Tu sesión en la nube expiró. Vuelve a conectar tu licencia.")

    private suspend fun applyLicence(licence: Licence) {
        prefs.saveLicence(licence)
        store.setReadOnly(!licence.writable)
    }

    /** Returns the server's message when pushing is blocked (read-only licence), else null. */
    private suspend fun push(): String? {
        repeat(MAX_PUSH_ROUNDS) {
            val rows = store.pending()
            if (rows.isEmpty()) return null
            val batch = ArrayList<Pair<OutboxEntity, PushChange>>()
            var size = 0
            for (row in rows) {
                val change = store.change(row)
                val bytes = api.pushSize(listOf(change))
                if (batch.isNotEmpty() && (size + bytes > MAX_PUSH_BYTES || batch.size >= MAX_PUSH_CHANGES)) break
                batch += row to change
                size += bytes
            }
            val response = try {
                withAuth { api.push(it, batch.map { pair -> pair.second }) }
            } catch (e: ApiException) {
                when {
                    e.status == 402 -> {
                        // Expired/suspended licence: keep the outbox for when it is renewed.
                        prefs.saveLicence(prefs.account().let { a -> Licence(a.plan ?: "", "expired", a.licenceExpiresAt ?: "", false) })
                        store.setReadOnly(true)
                        return e.message ?: "Tu licencia no permite guardar cambios."
                    }
                    e.status == 413 && batch.size == 1 -> {
                        store.ack(batch[0].first)
                        notify("Un registro es demasiado grande para sincronizarse (revisa sus imágenes).", true)
                        return@repeat
                    }
                    else -> throw e
                }
            }
            response.licence?.let { applyLicence(it) }
            val byKey = batch.associateBy { (row, _) -> row.entity to row.id }
            var progress = 0
            for (applied in response.applied) {
                val row = byKey[applied.entity to (SyncCodec.localId(applied.id) ?: applied.id)]?.first ?: continue
                store.ack(row)
                progress++
            }
            val messages = LinkedHashSet<String>()
            for (rejection in response.rejected) {
                val row = byKey[rejection.entity to (SyncCodec.localId(rejection.id) ?: rejection.id)]?.first ?: continue
                progress++
                val server = rejection.server
                if (rejection.reason == "stale" && server != null) {
                    store.apply(listOf(server), force = true)
                } else {
                    store.ack(row)
                    if (rejection.reason != "stale") messages += rejection.message
                }
            }
            if (messages.isNotEmpty()) notify(messages.joinToString("\n"), true)
            if (progress == 0) return null
        }
        return null
    }

    private suspend fun pull() {
        val start = store.cursor()
        var cursor = start
        val changes = ArrayList<ServerChange>()
        var pages = 0
        do {
            val page = withAuth { api.pull(it, cursor, PULL_PAGE) }
            changes += page.changes
            cursor = page.cursor
            page.licence?.let { applyLicence(it) }
        } while (page.hasMore && ++pages < MAX_PULL_PAGES)
        if (changes.isNotEmpty() || cursor != start) store.apply(changes, cursor = cursor)
    }

    companion object {
        const val DEFAULT_API_BASE = "https://trama-app.vercel.app/api"
        private const val WRITE_DEBOUNCE_MS = 3_000L
        private const val MAX_PUSH_ROUNDS = 50
        private const val MAX_PUSH_CHANGES = 200
        /** The server caps bodies at 4 MB (Vercel at 4.5 MB). */
        private const val MAX_PUSH_BYTES = 3_500_000
        private const val PULL_PAGE = 500
        private const val MAX_PULL_PAGES = 1_000
    }
}
