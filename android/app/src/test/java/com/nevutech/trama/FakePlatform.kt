package com.nevutech.trama

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.net.InetSocketAddress
import java.time.Instant
import java.util.UUID

/**
 * In-process stand-in for platform/ (same routes, JSON shapes and error envelope), small enough to
 * reason about in tests: one company, last-writer-wins records, rotating tokens.
 */
class FakePlatform : AutoCloseable {
    data class Record(val entity: String, val id: String, val updatedAt: String, val deleted: Boolean, val data: JsonObject?, val version: Long)

    val records = LinkedHashMap<Pair<String, String>, Record>()
    var version = 0L
    var writable = true
    var accessToken = "access-1"
    var refreshToken = "refresh-token-000000000001"
    var loginError: Pair<Int, Pair<String, String>>? = null
    var forbidEntities = setOf<String>()
    val requests = mutableListOf<String>()
    val pushes = mutableListOf<JsonArray>()
    val userId = "7a1b2c3d-0000-4000-8000-000000000001"
    val userEmail = "admin@empresa.mx"
    var userData: JsonObject = buildJsonObject {
        put("id", userId); put("email", userEmail); put("firstName", "Ana"); put("lastName", "Nube")
        put("roleRaw", "Administrador"); put("isActive", true)
        put("passwordHash", "hash"); put("passwordSalt", "salt")
        put("createdAt", "2026-10-01T00:00:00.000Z"); put("updatedAt", "2026-10-01T00:00:00.000Z")
    }

    private val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0).apply {
        createContext("/api") { exchange -> runCatching { handle(exchange) }.onFailure { respond(exchange, 500, error("server_error", it.toString())) } }
        start()
    }
    val baseUrl = "http://127.0.0.1:${server.address.port}/api"

    fun put(entity: String, id: String, updatedAt: String, data: JsonObject?, deleted: Boolean = false) {
        records[entity to id.lowercase()] = Record(entity, id.lowercase(), updatedAt, deleted, data, ++version)
    }

    private fun licence() = buildJsonObject {
        put("plan", "planta"); put("status", if (writable) "active" else "expired"); put("expiresAt", "2027-01-01T00:00:00.000Z"); put("writable", writable)
    }

    private fun session() = buildJsonObject {
        put("accessToken", accessToken); put("refreshToken", refreshToken); put("expiresIn", 900)
        put("user", userData)
        put("tenant", buildJsonObject { put("id", "5e000000-0000-4000-8000-000000000001"); put("name", "Textiles Nube"); put("plan", "planta") })
        put("licence", licence())
    }

    private fun error(code: String, message: String) = buildJsonObject { put("error", buildJsonObject { put("code", code); put("message", message) }) }

    private fun change(r: Record) = buildJsonObject {
        put("entity", r.entity); put("id", r.id); put("updatedAt", r.updatedAt); put("deleted", r.deleted)
        put("data", r.data ?: JsonNull); put("version", r.version)
    }

    private fun handle(exchange: HttpExchange) {
        val path = exchange.requestURI.path.removePrefix("/api")
        val query = exchange.requestURI.query.orEmpty().split("&").filter { it.contains("=") }.associate { it.substringBefore("=") to it.substringAfter("=") }
        val body = exchange.requestBody.readBytes().toString(Charsets.UTF_8).takeIf { it.isNotBlank() }?.let { Json.parseToJsonElement(it).jsonObject }
        requests += "${exchange.requestMethod} $path"
        val authorized = exchange.requestHeaders.getFirst("Authorization") == "Bearer $accessToken"
        when (path) {
            "/auth/login" -> {
                loginError?.let { (status, e) -> return respond(exchange, status, error(e.first, e.second)) }
                check(body!!["device"]!!.jsonObject["platform"]!!.jsonPrimitive.content == "android")
                respond(exchange, 200, session())
            }
            "/auth/refresh" -> {
                if (body!!["refreshToken"]!!.jsonPrimitive.content != refreshToken) return respond(exchange, 401, error("refresh_invalid", "Tu sesión expiró. Vuelve a iniciar sesión."))
                accessToken = "access-${UUID.randomUUID()}"
                refreshToken = "refresh-${UUID.randomUUID()}"
                respond(exchange, 200, session())
            }
            "/auth/logout" -> if (!authorized) unauthorized(exchange) else { refreshToken = "revoked-${UUID.randomUUID()}"; respond(exchange, 200, buildJsonObject { put("ok", true) }) }
            "/sync/pull" -> {
                if (!authorized) return unauthorized(exchange)
                val cursor = query["cursor"]!!.toLong()
                val limit = query["limit"]!!.toInt()
                val after = records.values.filter { it.version > cursor }.sortedBy { it.version }
                val page = after.take(limit)
                respond(exchange, 200, buildJsonObject {
                    put("changes", JsonArray(page.map(::change)))
                    put("cursor", page.lastOrNull()?.version ?: cursor)
                    put("hasMore", after.size > limit)
                    put("licence", licence())
                })
            }
            "/sync/push" -> {
                if (!authorized) return unauthorized(exchange)
                if (!writable) return respond(exchange, 402, error("licence_inactive", "Tu licencia venció: los datos son de solo lectura."))
                val changes = body!!["changes"]!!.jsonArray
                pushes += changes
                val applied = mutableListOf<JsonElement>()
                val rejected = mutableListOf<JsonElement>()
                for (c in changes.map { it.jsonObject }) {
                    val entity = c["entity"]!!.jsonPrimitive.content
                    val id = c["id"]!!.jsonPrimitive.content
                    val updatedAt = c["updatedAt"]!!.jsonPrimitive.content
                    val existing = records[entity to id.lowercase()]
                    when {
                        entity in forbidEntities -> rejected += buildJsonObject {
                            put("entity", entity); put("id", id); put("reason", "forbidden"); put("message", "Tu puesto no permite este cambio.")
                        }
                        existing != null && Instant.parse(existing.updatedAt).isAfter(Instant.parse(updatedAt)) -> rejected += buildJsonObject {
                            put("entity", entity); put("id", id); put("reason", "stale"); put("message", "Hay una versión más reciente."); put("server", change(existing))
                        }
                        else -> {
                            val deleted = c["deleted"]?.jsonPrimitive?.booleanOrNull ?: false
                            put(entity, id, updatedAt, if (deleted) null else c["data"]!!.jsonObject, deleted)
                            applied += buildJsonObject { put("entity", entity); put("id", id); put("version", version) }
                        }
                    }
                }
                respond(exchange, 200, buildJsonObject {
                    put("applied", JsonArray(applied)); put("rejected", JsonArray(rejected)); put("licence", licence())
                })
            }
            else -> respond(exchange, 404, error("not_found", "Ruta no encontrada."))
        }
    }

    private fun unauthorized(exchange: HttpExchange) = respond(exchange, 401, error("token_invalid", "Tu sesión expiró. Vuelve a iniciar sesión."))

    private fun respond(exchange: HttpExchange, status: Int, body: JsonObject) {
        val bytes = body.toString().toByteArray(Charsets.UTF_8)
        exchange.responseHeaders.add("Content-Type", "application/json")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }

    override fun close() = server.stop(0)
}
