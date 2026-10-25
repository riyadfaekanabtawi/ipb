package com.nevutech.trama.core.data

import androidx.room.withTransaction
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.domain.UserPolicy
import java.time.LocalDate

/** Catalog kinds that share the name rules, with their Spanish wording. */
enum class CatalogKind(val genitive: String, val indefinite: String) {
    Plant("de la planta", "una planta"),
    Client("del cliente", "un cliente"),
    Supplier("del proveedor", "un proveedor"),
    Style("del estilo", "un estilo"),
}

/** User-facing validation messages, identical to ios CatalogService.CatalogError. */
object CatalogErrors {
    fun emptyName(kind: CatalogKind) = "Escribe el nombre ${kind.genitive}."
    fun duplicateName(kind: CatalogKind) = "Ya existe ${kind.indefinite} con ese nombre."
    const val INVALID_CAPACITY = "La capacidad máxima mensual debe ser mayor a cero."
    fun invalidEmail(email: String) = "El correo «$email» no es válido."
    const val MISSING_PROJECT_CLIENT = "Elige un cliente o escribe su nombre."
    const val NEGATIVE_AMOUNT = "Cantidad, precio y minutaje no pueden ser negativos."
    const val EMPTY_USER_NAME = "Escribe el nombre y el correo del usuario."
    const val PLANT_REQUIRED = "Un gerente de planta debe tener una planta asignada."
}

/** What an editor wants done with an image slot. */
sealed interface ImageEdit {
    data object Keep : ImageEdit
    data object Remove : ImageEdit
    class Replace(val bytes: ByteArray) : ImageEdit
}

/** Editable copy of a contact, so editors can be cancelled without touching the database. */
data class ContactDraft(
    val id: String = newId(),
    val name: String = "",
    val role: String = "",
    val email: String = "",
    val phone: String = "",
) {
    val isEmpty: Boolean get() = listOf(name, role, email, phone).all { it.isBlank() }
    fun trimmed() = copy(name = name.trim(), role = role.trim(), email = email.trim(), phone = phone.trim())

    companion object {
        fun of(contact: ContactEntity) = ContactDraft(
            contact.id, contact.name.orEmpty(), contact.role.orEmpty(), contact.email.orEmpty(), contact.phone.orEmpty(),
        )
    }
}

data class ProjectDraft(
    val clientId: String? = null,
    val clientName: String = "",
    val quantity: Long = 0,
    val price: Double = 0.0,
    val minutes: Double = 0.0,
    val fabric: String = "",
    val status: ProjectStatus = ProjectStatus.Pending,
    val deliveryDate: LocalDate? = null,
    val notes: String = "",
    val photo: ImageEdit = ImageEdit.Keep,
) {
    val total: Double get() = quantity * price

    companion object {
        fun of(project: ProjectEntity) = ProjectDraft(
            clientId = project.clientId,
            clientName = if (project.clientId == null) project.clientName.orEmpty() else "",
            quantity = project.quantity, price = project.price, minutes = project.minutes,
            fabric = project.fabric.orEmpty(), status = project.statusValue,
            deliveryDate = project.deliveryDate?.toLocalDate(), notes = project.notes.orEmpty(),
        )
    }
}

data class UserDraft(
    val firstName: String = "",
    val lastName: String = "",
    val email: String = "",
    val phone: String = "",
    val role: Role = Role.PlantManager,
    val plantId: String? = null,
    val avatar: ImageEdit = ImageEdit.Keep,
) {
    companion object {
        fun of(user: UserEntity) = UserDraft(
            user.firstName, user.lastName, user.email, user.phone, user.roleValue, user.plantId,
        )
    }
}

/**
 * Writes for the catalogs (plants, clients, suppliers, styles, projects, users). Port of
 * ios CatalogService.swift: validation and bookkeeping live here instead of in screens.
 */
class CatalogService(private val db: TramaDatabase, private val images: ImageStore) {
    private val dao = db.dao()

    // Plants

    suspend fun savePlant(existing: PlantEntity?, name: String, maxCapacity: Double): PlantEntity = db.withTransaction {
        val clean = validName(name, CatalogKind.Plant, "plant", existing?.id)
        if (!(maxCapacity > 0) || !maxCapacity.isFinite()) throw ServiceException(CatalogErrors.INVALID_CAPACITY)
        val plant = (existing ?: PlantEntity(name = "", maxCapacity = 0.0)).copy(name = clean, maxCapacity = maxCapacity, updatedAt = now())
        dao.upsert(plant)
        plant
    }

    // Clients / suppliers

    suspend fun saveClient(existing: ClientEntity?, name: String, address: String, contacts: List<ContactDraft>): ClientEntity = db.withTransaction {
        val clean = validName(name, CatalogKind.Client, "client", existing?.id)
        val drafts = validContacts(contacts)
        val client = (existing ?: ClientEntity(name = "")).copy(name = clean, address = address.trim().ifEmpty { null }, updatedAt = now())
        dao.upsert(client)
        dao.deleteContactsOfClient(client.id)
        drafts.forEachIndexed { i, d -> dao.upsert(d.toEntity(i).copy(clientId = client.id)) }
        client
    }

    suspend fun saveSupplier(existing: SupplierEntity?, name: String, address: String, contacts: List<ContactDraft>): SupplierEntity = db.withTransaction {
        val clean = validName(name, CatalogKind.Supplier, "supplier", existing?.id)
        val drafts = validContacts(contacts)
        val supplier = (existing ?: SupplierEntity(name = "")).copy(name = clean, address = address.trim().ifEmpty { null }, updatedAt = now())
        dao.upsert(supplier)
        dao.deleteContactsOfSupplier(supplier.id)
        drafts.forEachIndexed { i, d -> dao.upsert(d.toEntity(i).copy(supplierId = supplier.id)) }
        supplier
    }

    suspend fun deleteSupplier(supplier: SupplierEntity) = db.withTransaction { dao.delete(supplier) }

    // Styles

    suspend fun saveStyle(existing: StyleEntity?, name: String, image: ImageEdit = ImageEdit.Keep): StyleEntity =
        withImage(existing?.imageFile, image) { file ->
            db.withTransaction {
                val clean = validName(name, CatalogKind.Style, "style", existing?.id)
                val style = (existing ?: StyleEntity(name = "")).copy(name = clean, imageFile = file, updatedAt = now())
                dao.upsert(style)
                style
            }
        }

    /** Orders that use the style keep existing with no style (FK set null). */
    suspend fun deleteStyle(style: StyleEntity) {
        db.withTransaction { dao.delete(style) }
        images.delete(style.imageFile)
    }

    // Projects

    suspend fun saveProject(existing: ProjectEntity?, draft: ProjectDraft): ProjectEntity =
        withImage(existing?.photoFile, draft.photo) { file ->
            db.withTransaction {
                val freeName = draft.clientName.trim()
                val client = draft.clientId?.let { id -> clientRef(id) }
                if (client == null && freeName.isEmpty()) throw ServiceException(CatalogErrors.MISSING_PROJECT_CLIENT)
                if (draft.quantity < 0 || draft.price < 0 || draft.minutes < 0) throw ServiceException(CatalogErrors.NEGATIVE_AMOUNT)
                val project = (existing ?: ProjectEntity()).copy(
                    clientId = client?.id,
                    // Keep the name too, so the project still reads well if the client is deleted later.
                    clientName = client?.name ?: freeName,
                    quantity = draft.quantity, price = draft.price, minutes = draft.minutes,
                    fabric = draft.fabric.trim().ifEmpty { null }, status = draft.status.raw,
                    deliveryDate = draft.deliveryDate?.toEpochMillis(), notes = draft.notes.trim().ifEmpty { null },
                    photoFile = file, updatedAt = now(),
                )
                dao.upsert(project)
                project
            }
        }

    suspend fun setProjectStatus(project: ProjectEntity, status: ProjectStatus) = db.withTransaction {
        dao.upsert(project.copy(status = status.raw, updatedAt = now()))
    }

    suspend fun deleteProject(project: ProjectEntity) {
        db.withTransaction { dao.delete(project) }
        images.delete(project.photoFile)
    }

    // Users

    suspend fun createUser(draft: UserDraft, password: String): UserEntity {
        // Validate before writing the avatar so a rejected draft leaves no orphan file.
        val clean = db.withTransaction { validUser(draft, excludingId = null) }
        if (password.length < 6) throw AuthException(AuthError.WeakPassword)
        return withImage(null, draft.avatar) { file ->
            db.withTransaction {
                Session.createUser(
                    dao, clean.firstName, clean.lastName, clean.email, clean.phone, password, clean.role,
                    clean.plantId, avatarFile = file,
                )
            }
        }
    }

    suspend fun updateUser(user: UserEntity, draft: UserDraft, actingUserId: String?): UserEntity {
        // Validate before writing a new avatar; the write re-checks inside its own transaction.
        db.withTransaction {
            validUser(draft, excludingId = user.id)
            checkPolicy(UserPolicy.Change.ChangeRole(draft.role), user, actingUserId)
        }
        return withImage(user.avatarFile, draft.avatar) { file ->
            db.withTransaction {
                val clean = validUser(draft, excludingId = user.id)
                checkPolicy(UserPolicy.Change.ChangeRole(clean.role), user, actingUserId)
                val updated = (dao.user(user.id) ?: user).copy(
                    firstName = clean.firstName, lastName = clean.lastName, email = clean.email, phone = clean.phone,
                    role = clean.role.raw, plantId = if (clean.role == Role.PlantManager) clean.plantId else null,
                    avatarFile = file, updatedAt = now(),
                )
                dao.upsert(updated)
                updated
            }
        }
    }

    suspend fun setActive(user: UserEntity, active: Boolean, actingUserId: String?) = db.withTransaction {
        if (!active) checkPolicy(UserPolicy.Change.Deactivate, user, actingUserId)
        val current = dao.user(user.id) ?: user
        dao.upsert(current.copy(isActive = active, updatedAt = now()))
    }

    suspend fun resetPassword(user: UserEntity, password: String) = db.withTransaction {
        if (password.length < 6) throw AuthException(AuthError.WeakPassword)
        dao.upsert(Session.withPassword(dao.user(user.id) ?: user, password))
    }

    suspend fun deleteUser(user: UserEntity, actingUserId: String?) {
        db.withTransaction {
            checkPolicy(UserPolicy.Change.Delete, user, actingUserId)
            dao.delete(user)
        }
        images.delete(user.avatarFile)
    }

    // Helpers

    private suspend fun checkPolicy(change: UserPolicy.Change, user: UserEntity, actingUserId: String?) {
        val members = dao.allUsers().map { it.member() }
        val target = (dao.user(user.id) ?: user).member()
        UserPolicy.violation(change, target, actingUserId, members)?.let { throw ServiceException(it.message) }
    }

    private suspend fun validUser(draft: UserDraft, excludingId: String?): UserDraft {
        val clean = draft.copy(
            firstName = draft.firstName.trim(), lastName = draft.lastName.trim(),
            email = draft.email.trim().lowercase(), phone = draft.phone.trim(),
        )
        if (clean.firstName.isEmpty() || clean.email.isEmpty()) throw ServiceException(CatalogErrors.EMPTY_USER_NAME)
        if (!ContactLinks.isPlausibleEmail(clean.email)) throw ServiceException(CatalogErrors.invalidEmail(clean.email))
        // Legacy rule: plant managers can only exist with a plant.
        if (clean.role == Role.PlantManager && (clean.plantId == null || dao.plant(clean.plantId) == null)) {
            throw ServiceException(CatalogErrors.PLANT_REQUIRED)
        }
        val existing = dao.userByEmail(clean.email)
        if (existing != null && existing.id != excludingId) throw AuthException(AuthError.EmailTaken)
        return clean
    }

    /** Trims and rejects empty or case-insensitively duplicated names within [table]. */
    private fun validName(raw: String, kind: CatalogKind, table: String, excludingId: String?): String {
        val name = raw.trim()
        if (name.isEmpty()) throw ServiceException(CatalogErrors.emptyName(kind))
        val key = name.lowercase()
        val duplicate = db.query("SELECT id, name FROM $table", null).use { c ->
            var found = false
            while (!found && c.moveToNext()) found = c.getString(0) != excludingId && c.getString(1).trim().lowercase() == key
            found
        }
        if (duplicate) throw ServiceException(CatalogErrors.duplicateName(kind))
        return name
    }

    private fun validContacts(drafts: List<ContactDraft>): List<ContactDraft> {
        val cleaned = drafts.map { it.trimmed() }.filterNot { it.isEmpty }
        cleaned.firstOrNull { it.email.isNotEmpty() && !ContactLinks.isPlausibleEmail(it.email) }
            ?.let { throw ServiceException(CatalogErrors.invalidEmail(it.email)) }
        return cleaned
    }

    private fun ContactDraft.toEntity(index: Int) = ContactEntity(
        id = id, name = name.ifEmpty { null }, role = role.ifEmpty { null }, email = email.ifEmpty { null },
        phone = phone.ifEmpty { null }, sortIndex = index,
    )

    /** Client id + name inside a transaction (the DAO has no one-shot client read). */
    private fun clientRef(id: String): ClientEntity? =
        db.query("SELECT id, name FROM client WHERE id = ?", arrayOf(id)).use { c ->
            if (c.moveToFirst()) ClientEntity(id = c.getString(0), name = c.getString(1)) else null
        }

    /**
     * Resolves the image slot to a file name, runs [write], then removes whichever file is no
     * longer referenced: the old one on success, the freshly written one on failure.
     */
    private suspend fun <T> withImage(current: String?, edit: ImageEdit, write: suspend (String?) -> T): T {
        val fresh = (edit as? ImageEdit.Replace)?.let { images.save(it.bytes) }
        val target = when (edit) {
            ImageEdit.Keep -> current
            ImageEdit.Remove -> null
            is ImageEdit.Replace -> fresh
        }
        val result = try {
            write(target)
        } catch (e: Throwable) {
            images.delete(fresh)
            throw e
        }
        if (current != null && current != target) images.delete(current)
        return result
    }
}

private fun UserEntity.member() = UserPolicy.Member(id, roleValue, isActive)

/** `mailto:` / `tel:` builders for contact cards (port of ios ContactLinks). */
object ContactLinks {
    fun isPlausibleEmail(email: String): Boolean {
        val parts = email.split("@")
        if (parts.size != 2 || parts[0].isEmpty() || email.any { it.isWhitespace() }) return false
        val domain = parts[1]
        return domain.contains(".") && !domain.startsWith(".") && !domain.endsWith(".")
    }

    /** One mailto for several recipients; null when none of them is a usable address. */
    fun mailto(emails: List<String?>): String? {
        val seen = HashSet<String>()
        val recipients = emails.filterNotNull().map { it.trim() }.filter { isPlausibleEmail(it) && seen.add(it.lowercase()) }
        if (recipients.isEmpty()) return null
        return "mailto:" + recipients.joinToString(",")
    }

    fun tel(phone: String?): String? {
        val digits = phone.orEmpty().filter { it.isDigit() || it == '+' }
        return if (digits.length >= 7) "tel:$digits" else null
    }
}
