import CoreData
import Foundation

/// Writes for the catalogs (plants, clients, suppliers, styles, projects, users).
/// They carry no production rules, but validation and bookkeeping still live in one place
/// instead of being scattered across views.
struct CatalogService {
    let context: NSManagedObjectContext

    enum Kind {
        case plant, client, supplier, style

        fileprivate var genitive: String {
            switch self {
            case .plant: "de la planta"
            case .client: "del cliente"
            case .supplier: "del proveedor"
            case .style: "del estilo"
            }
        }

        fileprivate var indefinite: String {
            switch self {
            case .plant: "una planta"
            case .client: "un cliente"
            case .supplier: "un proveedor"
            case .style: "un estilo"
            }
        }
    }

    enum CatalogError: LocalizedError, Equatable {
        case emptyName(Kind)
        case duplicateName(Kind)
        case invalidCapacity
        case invalidEmail(String)
        case missingProjectClient
        case negativeAmount
        case emptyUserName
        case plantRequired

        var errorDescription: String? {
            switch self {
            case .emptyName(let kind): "Escribe el nombre \(kind.genitive)."
            case .duplicateName(let kind): "Ya existe \(kind.indefinite) con ese nombre."
            case .invalidCapacity: "La capacidad máxima mensual debe ser mayor a cero."
            case .invalidEmail(let email): "El correo «\(email)» no es válido."
            case .missingProjectClient: "Elige un cliente o escribe su nombre."
            case .negativeAmount: "Cantidad, precio y minutaje no pueden ser negativos."
            case .emptyUserName: "Escribe el nombre y el correo del usuario."
            case .plantRequired: "Un gerente de planta debe tener una planta asignada."
            }
        }
    }

    // MARK: Plants

    @discardableResult
    func savePlant(_ plant: Plant?, name: String, maxCapacity: Double) throws -> Plant {
        let name = try validName(name, kind: .plant, excluding: plant)
        guard maxCapacity > 0, maxCapacity.isFinite else { throw CatalogError.invalidCapacity }
        let target = plant ?? Plant(context: context)
        target.name = name
        target.maxCapacity = maxCapacity
        return try finish(target)
    }

    // MARK: Clients / suppliers

    @discardableResult
    func saveClient(_ client: Client?, name: String, address: String, contacts: [ContactDraft]) throws -> Client {
        let name = try validName(name, kind: .client, excluding: client)
        let drafts = try validContacts(contacts)
        let target = client ?? Client(context: context)
        target.name = name
        target.address = address.trimmed.nilIfEmpty
        sync(drafts, existing: target.contactList) { $0.client = target }
        return try finish(target)
    }

    @discardableResult
    func saveSupplier(_ supplier: Supplier?, name: String, address: String, contacts: [ContactDraft]) throws -> Supplier {
        let name = try validName(name, kind: .supplier, excluding: supplier)
        let drafts = try validContacts(contacts)
        let target = supplier ?? Supplier(context: context)
        target.name = name
        target.address = address.trimmed.nilIfEmpty
        sync(drafts, existing: target.contactList) { $0.supplier = target }
        return try finish(target)
    }

    // MARK: Styles

    @discardableResult
    func saveStyle(_ style: Style?, name: String, imageData: Data?) throws -> Style {
        let name = try validName(name, kind: .style, excluding: style)
        let target = style ?? Style(context: context)
        target.name = name
        target.imageData = imageData
        return try finish(target)
    }

    // MARK: Projects

    @discardableResult
    func saveProject(_ project: Project?, draft: ProjectDraft) throws -> Project {
        let freeName = draft.clientName.trimmed
        guard draft.client != nil || !freeName.isEmpty else { throw CatalogError.missingProjectClient }
        guard draft.quantity >= 0, draft.price >= 0, draft.minutes >= 0 else { throw CatalogError.negativeAmount }
        let target = project ?? Project(context: context)
        target.client = draft.client
        // Keep the name too, so the project still reads well if the client is deleted later.
        target.clientName = draft.client?.name ?? freeName
        target.quantity = Int64(draft.quantity)
        target.price = draft.price
        target.minutes = draft.minutes
        target.fabric = draft.fabric.trimmed.nilIfEmpty
        target.status = draft.status
        target.deliveryDate = draft.deliveryDate
        target.notes = draft.notes.trimmed.nilIfEmpty
        target.photoData = draft.photo
        return try finish(target)
    }

    func setStatus(_ status: ProjectStatus, of project: Project) throws {
        project.status = status
        _ = try finish(project)
    }

    // MARK: Users

    @discardableResult
    func createUser(_ draft: UserDraft, password: String) throws -> AppUser {
        let draft = try validUser(draft, excluding: nil)
        return try Session.createUser(
            firstName: draft.firstName, lastName: draft.lastName, email: draft.email, phone: draft.phone,
            password: password, role: draft.role, plant: draft.plant, avatar: draft.avatar, in: context)
    }

    func updateUser(_ user: AppUser, with draft: UserDraft, actingUser: AppUser?) throws {
        let draft = try validUser(draft, excluding: user)
        try check(.changeRole(draft.role), on: user, actingUser: actingUser)
        user.firstName = draft.firstName
        user.lastName = draft.lastName
        user.email = draft.email
        user.phone = draft.phone
        user.role = draft.role
        user.plant = draft.role == .plantManager ? draft.plant : nil
        user.avatarData = draft.avatar
        _ = try finish(user)
    }

    func setActive(_ active: Bool, for user: AppUser, actingUser: AppUser?) throws {
        if !active { try check(.deactivate, on: user, actingUser: actingUser) }
        user.isActive = active
        _ = try finish(user)
    }

    func resetPassword(_ password: String, for user: AppUser) throws {
        guard password.count >= 6 else { throw AuthError.weakPassword }
        Session.setPassword(password, for: user)
        _ = try finish(user)
    }

    func deleteUser(_ user: AppUser, actingUser: AppUser?) throws {
        try check(.delete, on: user, actingUser: actingUser)
        context.delete(user)
        try save()
    }

    // MARK: Helpers

    private func check(_ change: UserPolicy.Change, on user: AppUser, actingUser: AppUser?) throws {
        let members = context.fetchAll(AppUser.self).map(\.policyMember)
        if let violation = UserPolicy.violation(
            of: change, on: user.policyMember, actingUserID: actingUser?.policyMember.id, members: members)
        {
            throw violation
        }
    }

    private func validUser(_ draft: UserDraft, excluding user: AppUser?) throws -> UserDraft {
        var draft = draft
        draft.firstName = draft.firstName.trimmed
        draft.lastName = draft.lastName.trimmed
        draft.email = draft.email.trimmed.lowercased()
        draft.phone = draft.phone.trimmed
        guard !draft.firstName.isEmpty, !draft.email.isEmpty else { throw CatalogError.emptyUserName }
        guard ContactLinks.isPlausibleEmail(draft.email) else { throw CatalogError.invalidEmail(draft.email) }
        // Legacy rule: plant managers can only exist with a plant.
        if draft.role == .plantManager, draft.plant == nil { throw CatalogError.plantRequired }
        if let existing = Session.findUser(email: draft.email, in: context), existing != user { throw AuthError.emailTaken }
        return draft
    }

    private func validName<T: NSManagedObject>(_ raw: String, kind: Kind, excluding object: T?) throws -> String {
        let name = raw.trimmed
        guard !name.isEmpty else { throw CatalogError.emptyName(kind) }
        let duplicates = context.fetchAll(T.self, predicate: NSPredicate(format: "name ==[c] %@", name))
        if duplicates.contains(where: { $0 != object }) { throw CatalogError.duplicateName(kind) }
        return name
    }

    private func validContacts(_ drafts: [ContactDraft]) throws -> [ContactDraft] {
        let cleaned = drafts.map(\.trimmed).filter { !$0.isEmpty }
        if let bad = cleaned.first(where: { !$0.email.isEmpty && !ContactLinks.isPlausibleEmail($0.email) }) {
            throw CatalogError.invalidEmail(bad.email)
        }
        return cleaned
    }

    /// Updates contacts in place by id, deleting removed ones and appending new ones in draft order.
    private func sync(_ drafts: [ContactDraft], existing: [Contact], attach: (Contact) -> Void) {
        let keep = Set(drafts.map(\.id))
        for contact in existing where !keep.contains(contact.id ?? UUID()) { context.delete(contact) }
        let byID = Dictionary(existing.compactMap { c in c.id.map { ($0, c) } }, uniquingKeysWith: { first, _ in first })
        for (index, draft) in drafts.enumerated() {
            let contact =
                byID[draft.id]
                ?? {
                    let new = Contact(context: context)
                    new.id = draft.id
                    attach(new)
                    return new
                }()
            contact.name = draft.name.nilIfEmpty
            contact.role = draft.role.nilIfEmpty
            contact.email = draft.email.nilIfEmpty
            contact.phone = draft.phone.nilIfEmpty
            contact.sortIndex = Int16(index)
        }
    }

    private func finish<T: Timestamped>(_ object: T) throws -> T {
        object.stampCreated()
        try save()
        return object
    }

    private func save() throws {
        do {
            try context.saveIfNeeded()
        } catch {
            context.rollback()
            throw error
        }
    }
}

// MARK: - Drafts

/// Editable copy of a contact, so sheets can be cancelled without touching Core Data.
struct ContactDraft: Identifiable, Equatable, Hashable {
    var id = UUID()
    var name = ""
    var role = ""
    var email = ""
    var phone = ""

    init(id: UUID = UUID(), name: String = "", role: String = "", email: String = "", phone: String = "") {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
        self.phone = phone
    }

    init(_ contact: Contact) {
        self.init(
            id: contact.id ?? UUID(), name: contact.name ?? "", role: contact.role ?? "",
            email: contact.email ?? "", phone: contact.phone ?? "")
    }

    var isEmpty: Bool { [name, role, email, phone].allSatisfy { $0.trimmed.isEmpty } }

    var trimmed: ContactDraft {
        ContactDraft(id: id, name: name.trimmed, role: role.trimmed, email: email.trimmed, phone: phone.trimmed)
    }
}

struct ProjectDraft: Equatable {
    var client: Client?
    var clientName = ""
    var quantity = 0
    var price: Double = 0
    var minutes: Double = 0
    var fabric = ""
    var status: ProjectStatus = .pending
    var deliveryDate: Date?
    var notes = ""
    var photo: Data?

    var total: Double { Double(quantity) * price }

    init() {}

    init(_ project: Project) {
        client = project.client
        clientName = project.client == nil ? (project.clientName ?? "") : ""
        quantity = Int(project.quantity)
        price = project.price
        minutes = project.minutes
        fabric = project.fabric ?? ""
        status = project.status
        deliveryDate = project.deliveryDate
        notes = project.notes ?? ""
        photo = project.photoData
    }
}

struct UserDraft: Equatable {
    var firstName = ""
    var lastName = ""
    var email = ""
    var phone = ""
    var role: Role = .plantManager
    var plant: Plant?
    var avatar: Data?

    init() {}

    init(_ user: AppUser) {
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        email = user.email ?? ""
        phone = user.phone ?? ""
        role = user.role
        plant = user.plant
        avatar = user.avatarData
    }
}

// MARK: - Contact links

/// `mailto:` / `tel:` builders for contact cards.
enum ContactLinks {
    static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !email.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    /// One mailto for several recipients; nil when none of them is a usable address.
    static func mailto(_ emails: [String]) -> URL? {
        var seen = Set<String>()
        let recipients = emails.map(\.trimmed).filter { isPlausibleEmail($0) && seen.insert($0.lowercased()).inserted }
        guard !recipients.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipients.joined(separator: ",")
        return components.url
    }

    static func tel(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard digits.count >= 7 else { return nil }
        return URL(string: "tel:\(digits)")
    }
}

// MARK: - Small helpers

extension AppUser {
    fileprivate var policyMember: UserPolicy.Member {
        // Unsaved users without an id still need a stable identity for the check.
        UserPolicy.Member(id: id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, role: role, isActive: isActive)
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
