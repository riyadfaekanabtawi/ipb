package com.nevutech.trama.core.data

import androidx.annotation.StringRes
import com.nevutech.trama.R
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.l10n.L10n
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

/**
 * Salted PBKDF2-HMAC-SHA256, identical parameters to iOS (120k iterations, 16-byte salt,
 * 32-byte key, base64), so users restored from an iPad backup can sign in on Android.
 */
object PasswordHasher {
    const val ITERATIONS = 120_000
    private const val KEY_BITS = 256

    fun makeSalt(): String = Base64.getEncoder().encodeToString(ByteArray(16).also { SecureRandom().nextBytes(it) })

    fun hash(password: String, salt: String): String {
        val saltBytes = runCatching { Base64.getDecoder().decode(salt) }.getOrElse { salt.toByteArray() }
        val spec = PBEKeySpec(password.toCharArray(), saltBytes, ITERATIONS, KEY_BITS)
        val key = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        return Base64.getEncoder().encodeToString(key)
    }

    /** Key derivation is deliberately slow (~0.5–1 s on phones): never run it on the main thread. */
    suspend fun hashAsync(password: String, salt: String): String = withContext(Dispatchers.Default) { hash(password, salt) }
    suspend fun verifyAsync(password: String, hash: String?, salt: String?): Boolean = withContext(Dispatchers.Default) { verify(password, hash, salt) }

    fun verify(password: String, hash: String?, salt: String?): Boolean {
        if (hash == null || salt == null) return false
        return MessageDigest.isEqual(hash(password, salt).toByteArray(), hash.toByteArray())
    }
}

enum class AuthError(@StringRes val messageRes: Int) {
    EmptyFields(R.string.auth_error_empty_fields),
    UnknownEmail(R.string.auth_error_unknown_email),
    WrongPassword(R.string.auth_error_wrong_password),
    Inactive(R.string.auth_error_inactive),
    EmailTaken(R.string.auth_error_email_taken),
    WeakPassword(R.string.auth_error_weak_password);

    val message: String get() = L10n.str(messageRes)
}

class AuthException(val error: AuthError) : Exception() {
    override val message: String get() = error.message
}

/** Current signed-in user. The session id is persisted so the tablet reopens straight into the app. */
class Session(private val dao: TramaDao, private val settings: SettingsStore) {
    private val _user = MutableStateFlow<UserEntity?>(null)
    val user: StateFlow<UserEntity?> = _user.asStateFlow()

    val role: Role get() = Role.fromRaw(_user.value?.role)

    fun service(db: TramaDatabase) = ProductionService(db, _user.value?.fullName)

    suspend fun restore() {
        val id = settings.sessionUserId() ?: return run { _user.value = null }
        _user.value = dao.user(id)?.takeIf { it.isActive }
    }

    suspend fun signIn(email: String, password: String) {
        val normalized = email.trim().lowercase()
        if (normalized.isEmpty() || password.isEmpty()) throw AuthException(AuthError.EmptyFields)
        val user = dao.userByEmail(normalized) ?: throw AuthException(AuthError.UnknownEmail)
        if (!PasswordHasher.verifyAsync(password, user.passwordHash, user.passwordSalt)) throw AuthException(AuthError.WrongPassword)
        if (!user.isActive) throw AuthException(AuthError.Inactive)
        adopt(user)
    }

    suspend fun adopt(user: UserEntity) {
        _user.value = user
        settings.setSessionUserId(user.id)
    }

    suspend fun signOut() {
        _user.value = null
        settings.setSessionUserId(null)
    }

    /**
     * Keeps the in-memory user fresh after edits (role change, deactivation, restore). Graph
     * snapshots can lag behind writes (or still be the initial empty graph), so a user missing
     * from the graph is confirmed against the database before signing them out.
     */
    suspend fun refresh(graph: Graph) {
        val current = _user.value ?: return
        val fromGraph = graph.user(current.id)
        _user.value = if (fromGraph != null) fromGraph.takeIf { it.isActive } else dao.user(current.id)?.takeIf { it.isActive }
    }

    companion object {
        suspend fun createUser(
            dao: TramaDao, firstName: String, lastName: String, email: String, phone: String, password: String,
            role: Role, plantId: String?, avatarFile: String? = null,
        ): UserEntity {
            val normalized = email.trim().lowercase()
            if (firstName.isBlank() || normalized.isEmpty()) throw AuthException(AuthError.EmptyFields)
            if (password.length < 6) throw AuthException(AuthError.WeakPassword)
            if (dao.userByEmail(normalized) != null) throw AuthException(AuthError.EmailTaken)
            val salt = PasswordHasher.makeSalt()
            val user = UserEntity(
                firstName = firstName.trim(), lastName = lastName.trim(), email = normalized, phone = phone.trim(),
                role = role.raw, passwordHash = PasswordHasher.hashAsync(password, salt), passwordSalt = salt,
                plantId = if (role == Role.PlantManager) plantId else null, avatarFile = avatarFile,
            )
            dao.insertUser(user)
            return user
        }

        suspend fun withPassword(user: UserEntity, password: String): UserEntity {
            val salt = PasswordHasher.makeSalt()
            return user.copy(passwordHash = PasswordHasher.hashAsync(password, salt), passwordSalt = salt, updatedAt = now())
        }
    }
}
