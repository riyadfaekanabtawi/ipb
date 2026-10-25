package com.nevutech.trama.core.data.sync

import com.nevutech.trama.R
import com.nevutech.trama.core.l10n.L10n
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.JsonObject

// Client for the Trama platform API (platform/src/app.ts, routes/auth.ts, sync.ts).
// Plain HttpURLConnection + kotlinx.serialization: no extra dependencies, and pure JVM so it is
// tested against a local HTTP server.

@Serializable data class DeviceInfo(val id: String, val platform: String = "android", val name: String? = null)

@Serializable data class Licence(val plan: String, val status: String, val expiresAt: String, val writable: Boolean)

@Serializable data class TenantInfo(
    val id: String,
    val name: String,
    val plan: String,
    val maxUsers: Int? = null,
    val maxDevices: Int? = null,
    val maxPlants: Int? = null,
)

@Serializable data class AuthResponse(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long = 900,
    /** AppUserDTO shape, including passwordHash/passwordSalt for offline sign-in. */
    val user: JsonObject,
    val tenant: TenantInfo,
    val licence: Licence,
)

@Serializable data class ServerChange(
    val entity: String,
    val id: String,
    val updatedAt: String,
    val deleted: Boolean = false,
    val data: JsonObject? = null,
    val version: Long = 0,
)

@Serializable data class PullResponse(val changes: List<ServerChange>, val cursor: Long, val hasMore: Boolean, val licence: Licence? = null)

@Serializable data class PushChange(
    val entity: String,
    val id: String,
    val updatedAt: String,
    val deleted: Boolean = false,
    val data: JsonObject? = null,
)

@Serializable data class Applied(val entity: String, val id: String, val version: Long)

@Serializable data class Rejection(
    val entity: String,
    val id: String,
    /** stale | forbidden | limit | conflict | invalid */
    val reason: String,
    val message: String,
    val server: ServerChange? = null,
)

@Serializable data class PushResponse(val applied: List<Applied>, val rejected: List<Rejection>, val licence: Licence? = null)

@Serializable private data class LoginBody(val email: String, val password: String, val device: DeviceInfo)
@Serializable private data class RefreshBody(val refreshToken: String)
@Serializable private data class PushBody(val changes: List<PushChange>)
@Serializable private data class ErrorBody(val error: ErrorDetail? = null)
@Serializable private data class ErrorDetail(val code: String? = null, val message: String? = null)
@Serializable private data class OkBody(val ok: Boolean = true)

/** The server answered with an error; [message] is its copy (localized via `Accept-Language`, shown as is). */
class ApiException(val status: Int, val code: String, message: String) : Exception(message)

/** The server couldn't be reached (offline, DNS, timeout). */
class OfflineException(cause: Throwable? = null) : Exception(cause) {
    override val message: String get() = L10n.str(R.string.api_error_offline)
}

/**
 * [language] is sent as `Accept-Language` on every request so the server answers in the app's
 * language (it falls back to Spanish when it doesn't support it).
 */
class TramaApi(private val language: () -> String = L10n::acceptLanguage, private val baseUrl: () -> String) {
    private val json = SyncCodec.json

    suspend fun login(email: String, password: String, device: DeviceInfo): AuthResponse =
        call("POST", "/auth/login", null, LoginBody(email, password, device), LoginBody.serializer(), AuthResponse.serializer())

    suspend fun refresh(refreshToken: String): AuthResponse =
        call("POST", "/auth/refresh", null, RefreshBody(refreshToken), RefreshBody.serializer(), AuthResponse.serializer())

    suspend fun logout(accessToken: String) {
        call("POST", "/auth/logout", accessToken, OkBody(), OkBody.serializer(), OkBody.serializer())
    }

    suspend fun pull(accessToken: String, cursor: Long, limit: Int = 500): PullResponse =
        call("GET", "/sync/pull?cursor=$cursor&limit=$limit", accessToken, null, Unit.serializer(), PullResponse.serializer())

    suspend fun push(accessToken: String, changes: List<PushChange>): PushResponse =
        call("POST", "/sync/push", accessToken, PushBody(changes), PushBody.serializer(), PushResponse.serializer())

    /** Encoded size of a push body, to keep requests under the server's 4 MB limit. */
    fun pushSize(changes: List<PushChange>): Int = json.encodeToString(PushBody.serializer(), PushBody(changes)).length

    private suspend fun <B, R> call(
        method: String, path: String, token: String?, body: B?, bodySerializer: KSerializer<B>, result: KSerializer<R>,
    ): R = withContext(Dispatchers.IO) {
        val connection = try {
            (URL(baseUrl().trimEnd('/') + path).openConnection() as HttpURLConnection)
        } catch (e: IOException) {
            throw OfflineException(e)
        }
        try {
            connection.requestMethod = method
            connection.connectTimeout = 15_000
            connection.readTimeout = 60_000
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Accept-Language", language())
            token?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            if (body != null) {
                val bytes = json.encodeToString(bodySerializer, body).toByteArray(Charsets.UTF_8)
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.setFixedLengthStreamingMode(bytes.size)
                connection.outputStream.use { it.write(bytes) }
            }
            val status = connection.responseCode
            val text = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.use { it.readBytes().toString(Charsets.UTF_8) }.orEmpty()
            if (status !in 200..299) throw error(status, text)
            try {
                json.decodeFromString(result, text)
            } catch (e: Exception) {
                throw ApiException(status, "bad_response", L10n.str(R.string.api_error_bad_response))
            }
        } catch (e: IOException) {
            throw OfflineException(e)
        } finally {
            connection.disconnect()
        }
    }

    private fun error(status: Int, text: String): ApiException {
        val detail = runCatching { json.decodeFromString(ErrorBody.serializer(), text).error }.getOrNull()
        val fallback = when (status) {
            401 -> L10n.str(R.string.api_error_session_expired)
            413 -> L10n.str(R.string.api_error_too_large)
            in 500..599 -> L10n.str(R.string.api_error_unavailable)
            else -> L10n.str(R.string.api_error_generic, status)
        }
        return ApiException(status, detail?.code ?: "http_$status", detail?.message ?: fallback)
    }
}
