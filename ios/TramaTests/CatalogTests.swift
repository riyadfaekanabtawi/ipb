import CoreData
import Foundation
import Testing

@testable import Trama

@Suite("Last-admin and self-protection rules")
struct UserPolicyTests {
    typealias Member = UserPolicy.Member

    let me = Member(id: UUID(), role: .admin, isActive: true)
    let otherAdmin = Member(id: UUID(), role: .admin, isActive: true)
    let manager = Member(id: UUID(), role: .plantManager, isActive: true)

    @Test func adminCannotDeleteOrDeactivateThemselves() {
        let members = [me, otherAdmin, manager]
        #expect(UserPolicy.violation(of: .delete, on: me, actingUserID: me.id, members: members) == .cannotDeleteSelf)
        #expect(UserPolicy.violation(of: .deactivate, on: me, actingUserID: me.id, members: members) == .cannotDeactivateSelf)
        #expect(
            UserPolicy.violation(of: .changeRole(.cutManager), on: me, actingUserID: me.id, members: members)
                == .cannotChangeOwnRole)
        // Saving your own profile without changing the role is fine.
        #expect(UserPolicy.violation(of: .changeRole(.admin), on: me, actingUserID: me.id, members: members) == nil)
    }

    @Test func lastActiveAdminIsProtected() {
        let inactiveAdmin = Member(id: UUID(), role: .admin, isActive: false)
        let members = [me, manager, inactiveAdmin]
        // Someone else (e.g. a session restored before a role change) acting on the only active admin.
        #expect(UserPolicy.violation(of: .delete, on: me, actingUserID: manager.id, members: members) == .lastAdmin)
        #expect(UserPolicy.violation(of: .deactivate, on: me, actingUserID: nil, members: members) == .lastAdmin)
        #expect(
            UserPolicy.violation(of: .changeRole(.shippingManager), on: me, actingUserID: nil, members: members) == .lastAdmin)
    }

    @Test func otherAdminsCanBeManagedWhileOneRemains() {
        let members = [me, otherAdmin, manager]
        #expect(UserPolicy.violation(of: .delete, on: otherAdmin, actingUserID: me.id, members: members) == nil)
        #expect(UserPolicy.violation(of: .deactivate, on: otherAdmin, actingUserID: me.id, members: members) == nil)
        #expect(
            UserPolicy.violation(of: .changeRole(.cutManager), on: otherAdmin, actingUserID: me.id, members: members) == nil)
        #expect(UserPolicy.violation(of: .delete, on: manager, actingUserID: me.id, members: members) == nil)
    }
}

@MainActor
@Suite("CatalogService")
struct CatalogServiceTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.viewContext }
    var service: CatalogService { CatalogService(context: context) }

    @Test func plantNamesAreTrimmedAndValidated() throws {
        let plant = try service.savePlant(nil, name: "  Planta Norte \n", maxCapacity: 1_000_000)
        #expect(plant.name == "Planta Norte")
        #expect(plant.id != nil && plant.createdAt != nil)

        #expect(throws: CatalogService.CatalogError.emptyName(.plant)) {
            try service.savePlant(nil, name: "   ", maxCapacity: 10)
        }
        #expect(throws: CatalogService.CatalogError.invalidCapacity) {
            try service.savePlant(nil, name: "Planta Sur", maxCapacity: 0)
        }
        #expect(throws: CatalogService.CatalogError.duplicateName(.plant)) {
            try service.savePlant(nil, name: "planta norte", maxCapacity: 10)
        }
        // Renaming the same plant to its own name is not a duplicate.
        try service.savePlant(plant, name: "Planta Norte", maxCapacity: 2_000_000)
        #expect(plant.maxCapacity == 2_000_000)
    }

    @Test func emptyNamesAreRejectedEverywhere() {
        #expect(throws: CatalogService.CatalogError.emptyName(.client)) {
            try service.saveClient(nil, name: "", address: "x", contacts: [])
        }
        #expect(throws: CatalogService.CatalogError.emptyName(.supplier)) {
            try service.saveSupplier(nil, name: " ", address: "", contacts: [])
        }
        #expect(throws: CatalogService.CatalogError.emptyName(.style)) {
            try service.saveStyle(nil, name: "\t", imageData: nil)
        }
        #expect(CatalogService.CatalogError.emptyName(.client).errorDescription == "Escribe el nombre del cliente.")
        #expect(context.count(Client.self) == 0)
    }

    @Test func contactsAreSyncedInOrderAndBlankRowsDropped() throws {
        let a = ContactDraft(name: " Laura ", role: "Compras", email: "laura@x.mx", phone: "")
        let b = ContactDraft(name: "Óscar", email: "oscar@x.mx")
        let client = try service.saveClient(nil, name: "Bayer", address: "  ", contacts: [a, ContactDraft(), b])
        #expect(client.address == nil)
        #expect(client.contactList.map(\.name) == ["Laura", "Óscar"])

        // Reorder, edit and remove: existing rows are updated in place, removed rows deleted.
        var edited = b
        edited.phone = "55 1234 5678"
        try service.saveClient(client, name: "Bayer", address: "CDMX", contacts: [edited])
        #expect(client.contactList.count == 1)
        #expect(client.contactList.first?.id == b.id)
        #expect(client.contactList.first?.phone == "55 1234 5678")
        #expect(context.count(Contact.self) == 1)
    }

    @Test func invalidContactEmailIsRejected() {
        #expect(throws: CatalogService.CatalogError.invalidEmail("laura@")) {
            try service.saveSupplier(nil, name: "Hilos", address: "", contacts: [ContactDraft(name: "L", email: "laura@")])
        }
        #expect(context.count(Supplier.self) == 0)
    }

    @Test func projectNeedsAClientAndComputesTotal() throws {
        var draft = ProjectDraft()
        draft.quantity = 1_000
        draft.price = 61.5
        #expect(draft.total == 61_500)
        #expect(throws: CatalogService.CatalogError.missingProjectClient) { try service.saveProject(nil, draft: draft) }

        draft.clientName = "  Prospecto Nuevo "
        let project = try service.saveProject(nil, draft: draft)
        #expect(project.displayClient == "Prospecto Nuevo")
        #expect(project.total == 61_500)

        try service.setStatus(.accepted, of: project)
        #expect(project.status == .accepted)

        draft.price = -1
        #expect(throws: CatalogService.CatalogError.negativeAmount) { try service.saveProject(project, draft: draft) }
    }

    @Test func plantManagerRequiresPlant() throws {
        var draft = UserDraft()
        draft.firstName = "Jorge"
        draft.email = "Jorge@DEMO.local "
        draft.role = .plantManager
        #expect(throws: CatalogService.CatalogError.plantRequired) { try service.createUser(draft, password: "secreto") }

        draft.plant = try service.savePlant(nil, name: "Planta Norte", maxCapacity: 1)
        let user = try service.createUser(draft, password: "secreto")
        #expect(user.email == "jorge@demo.local")
        #expect(user.plant != nil)

        #expect(throws: AuthError.emailTaken) { try service.createUser(draft, password: "secreto") }
    }

    @Test func serviceEnforcesLastAdminRule() throws {
        var adminDraft = UserDraft()
        adminDraft.firstName = "Riyad"
        adminDraft.email = "admin@demo.local"
        adminDraft.role = .admin
        let admin = try service.createUser(adminDraft, password: "secreto")

        var cutDraft = UserDraft()
        cutDraft.firstName = "Carmen"
        cutDraft.email = "cortes@demo.local"
        cutDraft.role = .cutManager
        let cutter = try service.createUser(cutDraft, password: "secreto")

        #expect(throws: UserPolicy.Violation.cannotDeleteSelf) { try service.deleteUser(admin, actingUser: admin) }
        #expect(throws: UserPolicy.Violation.cannotDeactivateSelf) {
            try service.setActive(false, for: admin, actingUser: admin)
        }
        #expect(throws: UserPolicy.Violation.lastAdmin) { try service.setActive(false, for: admin, actingUser: cutter) }
        #expect(admin.isActive)

        // Promote a second admin; now the first one can be deactivated by them.
        cutDraft.role = .admin
        try service.updateUser(cutter, with: cutDraft, actingUser: admin)
        try service.setActive(false, for: admin, actingUser: cutter)
        #expect(!admin.isActive)

        try service.deleteUser(admin, actingUser: cutter)
        #expect(context.count(AppUser.self) == 1)
    }

    @Test func resetPasswordRehashes() throws {
        var draft = UserDraft()
        draft.firstName = "Ana"
        draft.email = "envios@demo.local"
        draft.role = .shippingManager
        let user = try service.createUser(draft, password: "secreto")
        #expect(throws: AuthError.weakPassword) { try service.resetPassword("123", for: user) }
        try service.resetPassword("nueva-clave", for: user)
        #expect(PasswordHasher.verify("nueva-clave", hash: user.passwordHash, salt: user.passwordSalt))
        #expect(!PasswordHasher.verify("secreto", hash: user.passwordHash, salt: user.passwordSalt))
    }
}

@Suite("Contact links")
struct ContactLinkTests {
    @Test func mailtoJoinsUniqueValidAddresses() {
        let url = ContactLinks.mailto(["a@x.mx", " A@x.mx ", "bad", "", "b@y.com"])
        #expect(url?.absoluteString == "mailto:a@x.mx,b@y.com")
        #expect(ContactLinks.mailto(["nope"]) == nil)
    }

    @Test func telKeepsDigits() {
        #expect(ContactLinks.tel("55 2345-9988")?.absoluteString == "tel:5523459988")
        #expect(ContactLinks.tel("+52 (81) 1122 3344")?.absoluteString == "tel:+528111223344")
        #expect(ContactLinks.tel("123") == nil)
    }
}
