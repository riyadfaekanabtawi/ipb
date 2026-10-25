package com.nevutech.trama.core.data.sync

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.security.KeyStore
import java.util.Base64
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Encrypts small secrets at rest. */
interface SecretBox {
    fun seal(plain: ByteArray): ByteArray
    fun open(sealed: ByteArray): ByteArray
}

/**
 * AES-256-GCM with a non-exportable key in the Android Keystore (`iv ‖ ciphertext+tag`).
 * Replaces the deprecated security-crypto library with the few lines it actually needs.
 */
class KeystoreSecretBox(private val alias: String = "trama.sync.refresh") : SecretBox {
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    override fun seal(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        return cipher.iv + cipher.doFinal(plain)
    }

    override fun open(sealed: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, sealed.copyOfRange(0, 12)))
        return cipher.doFinal(sealed, 12, sealed.size - 12)
    }
}

private val Context.syncStore: DataStore<Preferences> by preferencesDataStore(name = "trama_sync")

/** What the device knows about its cloud link (shown in Ajustes → Nube). */
data class CloudAccount(
    val tenantId: String? = null,
    val tenantName: String? = null,
    val plan: String? = null,
    val email: String? = null,
    val licenceStatus: String? = null,
    val licenceExpiresAt: String? = null,
    val writable: Boolean = true,
    /** A refresh token is stored: the device is signed in to the cloud. */
    val connected: Boolean = false,
    val lastSyncAt: Long? = null,
    val lastError: String? = null,
)

/** Cloud link settings. The refresh token is stored sealed by [box]; the access token never touches disk. */
class SyncPrefs(private val store: DataStore<Preferences>, private val box: SecretBox) {
    constructor(context: Context) : this(context.syncStore, KeystoreSecretBox())

    private object Keys {
        val deviceId = stringPreferencesKey("device.id")
        val refresh = stringPreferencesKey("auth.refresh.sealed")
        val tenantId = stringPreferencesKey("tenant.id")
        val tenantName = stringPreferencesKey("tenant.name")
        val plan = stringPreferencesKey("tenant.plan")
        val email = stringPreferencesKey("account.email")
        val licenceStatus = stringPreferencesKey("licence.status")
        val licenceExpires = stringPreferencesKey("licence.expiresAt")
        val writable = booleanPreferencesKey("licence.writable")
        val lastSync = longPreferencesKey("sync.lastAt")
        val lastError = stringPreferencesKey("sync.lastError")
        val apiBase = stringPreferencesKey("api.baseOverride")
    }

    val account: Flow<CloudAccount> = store.data.map {
        CloudAccount(
            tenantId = it[Keys.tenantId], tenantName = it[Keys.tenantName], plan = it[Keys.plan], email = it[Keys.email],
            licenceStatus = it[Keys.licenceStatus], licenceExpiresAt = it[Keys.licenceExpires], writable = it[Keys.writable] ?: true,
            connected = it[Keys.refresh] != null, lastSyncAt = it[Keys.lastSync], lastError = it[Keys.lastError],
        )
    }

    suspend fun account(): CloudAccount = account.first()

    /** Stable per-install id; the server counts device seats by it. */
    suspend fun deviceId(): String {
        store.data.first()[Keys.deviceId]?.let { return it }
        val id = UUID.randomUUID().toString()
        store.edit { if (it[Keys.deviceId] == null) it[Keys.deviceId] = id }
        return store.data.first()[Keys.deviceId] ?: id
    }

    suspend fun refreshToken(): String? {
        val sealed = store.data.first()[Keys.refresh] ?: return null
        return runCatching { box.open(Base64.getDecoder().decode(sealed)).toString(Charsets.UTF_8) }.getOrNull()
    }

    suspend fun setRefreshToken(token: String?) {
        val sealed = token?.let { Base64.getEncoder().encodeToString(box.seal(it.toByteArray(Charsets.UTF_8))) }
        store.edit { if (sealed == null) it.remove(Keys.refresh) else it[Keys.refresh] = sealed }
    }

    suspend fun saveLink(tenant: TenantInfo, email: String) = store.edit {
        it[Keys.tenantId] = tenant.id
        it[Keys.tenantName] = tenant.name
        it[Keys.plan] = tenant.plan
        it[Keys.email] = email
    }

    suspend fun saveLicence(licence: Licence) = store.edit {
        it[Keys.licenceStatus] = licence.status
        it[Keys.licenceExpires] = licence.expiresAt
        it[Keys.writable] = licence.writable
        it[Keys.plan] = licence.plan
    }

    suspend fun recordSync(at: Long?, error: String?) = store.edit {
        if (at != null) it[Keys.lastSync] = at
        if (error == null) it.remove(Keys.lastError) else it[Keys.lastError] = error
    }

    /** Forgets the cloud link entirely (keeps the device id and any debug API override). */
    suspend fun forgetLink() = store.edit { prefs ->
        listOf(Keys.refresh, Keys.tenantId, Keys.tenantName, Keys.plan, Keys.email, Keys.licenceStatus, Keys.licenceExpires, Keys.lastSync, Keys.lastError)
            .forEach { prefs.remove(it) }
        prefs.remove(Keys.writable)
    }

    suspend fun apiBaseOverride(): String? = store.data.first()[Keys.apiBase]
    suspend fun setApiBaseOverride(url: String?) = store.edit { if (url.isNullOrBlank()) it.remove(Keys.apiBase) else it[Keys.apiBase] = url.trim() }
}
