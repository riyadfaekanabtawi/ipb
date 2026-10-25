package com.nevutech.trama

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.nevutech.trama.core.data.AuthError
import com.nevutech.trama.core.data.AuthException
import com.nevutech.trama.core.data.CatalogErrors
import com.nevutech.trama.core.data.CatalogKind
import com.nevutech.trama.core.data.CatalogService
import com.nevutech.trama.core.data.ContactDraft
import com.nevutech.trama.core.data.ContactLinks
import com.nevutech.trama.core.data.ImageEdit
import com.nevutech.trama.core.data.ImageStore
import com.nevutech.trama.core.data.PasswordHasher
import com.nevutech.trama.core.data.ProjectDraft
import com.nevutech.trama.core.data.ServiceException
import com.nevutech.trama.core.data.TramaDatabase
import com.nevutech.trama.core.data.UserDraft
import com.nevutech.trama.core.data.statusValue
import com.nevutech.trama.core.domain.ProjectStatus
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.core.domain.UserPolicy
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Port of ios/TramaTests/CatalogTests.swift (CatalogService + contact links). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CatalogTest {
    private lateinit var db: TramaDatabase
    private lateinit var images: ImageStore
    private lateinit var service: CatalogService

    @Before fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = TramaDatabase.inMemory(context)
        images = ImageStore(context).also { it.clear() }
        service = CatalogService(db, images)
    }

    @After fun tearDown() = db.close()

    private suspend fun failure(block: suspend () -> Unit): Throwable? = runCatching { block() }.exceptionOrNull()

    private suspend fun assertServiceError(message: String, block: suspend () -> Unit) {
        val error = failure(block)
        assertTrue("Expected ServiceException, got $error", error is ServiceException)
        assertEquals(message, error!!.message)
    }

    @Test fun plantNamesAreTrimmedAndValidated() = runTest {
        val plant = service.savePlant(null, "  Planta Norte \n", 1_000_000.0)
        assertEquals("Planta Norte", plant.name)

        assertServiceError(CatalogErrors.emptyName(CatalogKind.Plant)) { service.savePlant(null, "   ", 10.0) }
        assertServiceError(CatalogErrors.INVALID_CAPACITY) { service.savePlant(null, "Planta Sur", 0.0) }
        assertServiceError(CatalogErrors.INVALID_CAPACITY) { service.savePlant(null, "Planta Sur", Double.NaN) }
        assertServiceError(CatalogErrors.duplicateName(CatalogKind.Plant)) { service.savePlant(null, "planta NORTE", 10.0) }
        // Renaming the same plant to its own name is not a duplicate.
        val updated = service.savePlant(plant, "Planta Norte", 2_000_000.0)
        assertEquals(2_000_000.0, db.dao().plant(updated.id)!!.maxCapacity, 0.0)
        assertEquals(1, db.dao().plants().first().size)
    }

    @Test fun emptyAndDuplicateNamesAreRejectedEverywhere() = runTest {
        assertServiceError("Escribe el nombre del cliente.") { service.saveClient(null, "", "x", emptyList()) }
        assertServiceError(CatalogErrors.emptyName(CatalogKind.Supplier)) { service.saveSupplier(null, " ", "", emptyList()) }
        assertServiceError(CatalogErrors.emptyName(CatalogKind.Style)) { service.saveStyle(null, "\t") }
        assertEquals(0, db.dao().clients().first().size)

        service.saveClient(null, "Bayer", "", emptyList())
        service.saveSupplier(null, "Hilos Mexicanos", "", emptyList())
        service.saveStyle(null, "Falda Ñandú")
        assertServiceError("Ya existe un cliente con ese nombre.") { service.saveClient(null, " bayer ", "", emptyList()) }
        assertServiceError(CatalogErrors.duplicateName(CatalogKind.Supplier)) { service.saveSupplier(null, "HILOS MEXICANOS", "", emptyList()) }
        assertServiceError(CatalogErrors.duplicateName(CatalogKind.Style)) { service.saveStyle(null, "falda ñandú") }
        // Names are unique per catalog, not across catalogs.
        service.saveSupplier(null, "Bayer", "", emptyList())
    }

    @Test fun contactsAreReplacedInOrderAndBlankRowsDropped() = runTest {
        val a = ContactDraft(name = " Laura ", role = "Compras", email = "laura@x.mx")
        val b = ContactDraft(name = "Óscar", email = "oscar@x.mx")
        val client = service.saveClient(null, "Bayer", "  ", listOf(a, ContactDraft(), b))
        assertNull(client.address)
        val contacts = db.dao().contacts().first().filter { it.clientId == client.id }.sortedBy { it.sortIndex }
        assertEquals(listOf("Laura", "Óscar"), contacts.map { it.name })
        assertNull(contacts[0].phone)

        // Edit and remove: the kept row keeps its id, removed rows are deleted.
        service.saveClient(client, "Bayer", "CDMX", listOf(b.copy(phone = "55 1234 5678")))
        val after = db.dao().contacts().first()
        assertEquals(1, after.size)
        assertEquals(b.id, after[0].id)
        assertEquals("55 1234 5678", after[0].phone)
        assertEquals(0, after[0].sortIndex)
    }

    @Test fun supplierContactsAndInvalidEmail() = runTest {
        assertServiceError(CatalogErrors.invalidEmail("laura@")) {
            service.saveSupplier(null, "Hilos", "", listOf(ContactDraft(name = "L", email = "laura@")))
        }
        assertEquals(0, db.dao().suppliers().first().size)

        val s = service.saveSupplier(null, "Hilos", "Puebla", listOf(ContactDraft(name = "B"), ContactDraft(name = "A")))
        assertEquals(listOf("B", "A"), db.dao().contacts().first().filter { it.supplierId == s.id }.sortedBy { it.sortIndex }.map { it.name })
        service.deleteSupplier(s)
        assertEquals(0, db.dao().contacts().first().size)
    }

    @Test fun projectNeedsAClientAndComputesTotal() = runTest {
        var draft = ProjectDraft(quantity = 1_000, price = 61.5)
        assertEquals(61_500.0, draft.total, 0.0)
        assertServiceError(CatalogErrors.MISSING_PROJECT_CLIENT) { service.saveProject(null, draft) }

        draft = draft.copy(clientName = "  Prospecto Nuevo ")
        val project = service.saveProject(null, draft)
        assertEquals("Prospecto Nuevo", project.clientName)

        service.setProjectStatus(project, ProjectStatus.Accepted)
        assertEquals(ProjectStatus.Accepted, db.dao().projects().first().single().statusValue)

        assertServiceError(CatalogErrors.NEGATIVE_AMOUNT) { service.saveProject(project, draft.copy(price = -1.0)) }

        // A catalog client wins over the free text and its name is copied.
        val client = service.saveClient(null, "Bayer", "", emptyList())
        val linked = service.saveProject(project, draft.copy(clientId = client.id))
        assertEquals(client.id, linked.clientId)
        assertEquals("Bayer", linked.clientName)
    }

    @Test fun imagesAreReplacedAndOldFilesDeleted() = runTest {
        val style = service.saveStyle(null, "Falda", ImageEdit.Replace(byteArrayOf(1, 2, 3)))
        val first = style.imageFile
        assertNotNull(images.file(first))

        val replaced = service.saveStyle(style, "Falda", ImageEdit.Replace(byteArrayOf(4, 5)))
        assertNotNull(images.file(replaced.imageFile))
        assertNull(images.file(first))

        val kept = service.saveStyle(replaced, "Falda")
        assertEquals(replaced.imageFile, kept.imageFile)

        // A rejected save leaves no orphan file behind.
        service.saveStyle(null, "Blusa")
        assertTrue(failure { service.saveStyle(kept, "blusa", ImageEdit.Replace(byteArrayOf(9))) } is ServiceException)
        assertNotNull(images.file(kept.imageFile))

        val removed = service.saveStyle(kept, "Falda", ImageEdit.Remove)
        assertNull(removed.imageFile)
        assertNull(images.file(kept.imageFile))
    }

    @Test fun plantManagerRequiresPlant() = runTest {
        var draft = UserDraft(firstName = "Jorge", email = "Jorge@DEMO.local ", role = Role.PlantManager)
        assertServiceError(CatalogErrors.PLANT_REQUIRED) { service.createUser(draft, "secreto") }

        draft = draft.copy(plantId = service.savePlant(null, "Planta Norte", 1.0).id)
        val user = service.createUser(draft, "secreto")
        assertEquals("jorge@demo.local", user.email)
        assertNotNull(user.plantId)

        val taken = failure { service.createUser(draft, "secreto") }
        assertEquals(AuthError.EmailTaken, (taken as? AuthException)?.error)

        assertServiceError(CatalogErrors.invalidEmail("jorge@demo")) { service.createUser(draft.copy(email = "jorge@demo"), "secreto") }
        assertServiceError(CatalogErrors.EMPTY_USER_NAME) { service.createUser(draft.copy(firstName = " "), "secreto") }
        assertEquals(AuthError.WeakPassword, (failure { service.createUser(draft.copy(email = "x@y.mx"), "123") } as? AuthException)?.error)

        // Moving away from plant manager clears the plant.
        val cutter = service.updateUser(user, draft.copy(role = Role.CutManager), actingUserId = null)
        assertNull(cutter.plantId)
    }

    @Test fun serviceEnforcesLastAdminAndSelfRules() = runTest {
        val adminDraft = UserDraft(firstName = "Mariana", email = "admin@demo.local", role = Role.Admin)
        val admin = service.createUser(adminDraft, "secreto")
        val cutDraft = UserDraft(firstName = "Carmen", email = "cortes@demo.local", role = Role.CutManager)
        val cutter = service.createUser(cutDraft, "secreto")

        assertServiceError(UserPolicy.Violation.CannotDeleteSelf.message) { service.deleteUser(admin, admin.id) }
        assertServiceError(UserPolicy.Violation.CannotDeactivateSelf.message) { service.setActive(admin, false, admin.id) }
        assertServiceError(UserPolicy.Violation.CannotChangeOwnRole.message) {
            service.updateUser(admin, adminDraft.copy(role = Role.CutManager), admin.id)
        }
        assertServiceError(UserPolicy.Violation.LastAdmin.message) { service.setActive(admin, false, cutter.id) }
        assertServiceError(UserPolicy.Violation.LastAdmin.message) { service.updateUser(admin, adminDraft.copy(role = Role.ShippingManager), cutter.id) }
        assertTrue(db.dao().user(admin.id)!!.isActive)
        // Editing your own profile without changing the role is fine.
        service.updateUser(admin, adminDraft.copy(lastName = " Peña "), admin.id)
        assertEquals("Peña", db.dao().user(admin.id)!!.lastName)

        // Promote a second admin; now the first one can be deactivated and deleted by them.
        service.updateUser(cutter, cutDraft.copy(role = Role.Admin), admin.id)
        service.setActive(admin, false, cutter.id)
        assertFalse(db.dao().user(admin.id)!!.isActive)
        service.setActive(admin, true, cutter.id)
        service.deleteUser(admin, cutter.id)
        assertEquals(1, db.dao().userCount())
    }

    @Test fun resetPasswordRehashes() = runTest {
        val user = service.createUser(UserDraft(firstName = "Ana", email = "envios@demo.local", role = Role.ShippingManager), "secreto")
        assertEquals(AuthError.WeakPassword, (failure { service.resetPassword(user, "123") } as? AuthException)?.error)
        service.resetPassword(user, "nueva-clave")
        val stored = db.dao().user(user.id)!!
        assertTrue(PasswordHasher.verify("nueva-clave", stored.passwordHash, stored.passwordSalt))
        assertFalse(PasswordHasher.verify("secreto", stored.passwordHash, stored.passwordSalt))
    }

    @Test fun mailtoJoinsUniqueValidAddresses() {
        assertEquals("mailto:a@x.mx,b@y.com", ContactLinks.mailto(listOf("a@x.mx", " A@x.mx ", "bad", "", null, "b@y.com")))
        assertNull(ContactLinks.mailto(listOf("nope")))
    }

    @Test fun telKeepsDigits() {
        assertEquals("tel:5523459988", ContactLinks.tel("55 2345-9988"))
        assertEquals("tel:+528111223344", ContactLinks.tel("+52 (81) 1122 3344"))
        assertNull(ContactLinks.tel("123"))
    }
}
