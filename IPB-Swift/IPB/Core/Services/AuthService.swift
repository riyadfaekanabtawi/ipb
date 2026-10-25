import CommonCrypto
import CoreData
import Foundation
import Observation

/// Offline authentication against local users. Passwords are stored as salted PBKDF2-SHA256.
enum PasswordHasher {
    static let iterations: UInt32 = 120_000

    static func makeSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    static func hash(_ password: String, salt: String) -> String {
        let passwordData = Array(password.utf8).map { Int8(bitPattern: $0) }
        let saltData = Array(Data(base64Encoded: salt) ?? Data(salt.utf8))
        var derived = [UInt8](repeating: 0, count: 32)
        CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2), passwordData, passwordData.count,
            saltData, saltData.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            iterations, &derived, derived.count
        )
        return Data(derived).base64EncodedString()
    }

    static func verify(_ password: String, hash expected: String?, salt: String?) -> Bool {
        guard let expected, let salt else { return false }
        let actual = hash(password, salt: salt)
        // Constant-time compare.
        guard actual.count == expected.count else { return false }
        return zip(actual.utf8, expected.utf8).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

enum AuthError: LocalizedError, Equatable {
    case emptyFields
    case unknownEmail
    case wrongPassword
    case inactive
    case emailTaken
    case weakPassword

    var errorDescription: String? {
        switch self {
        case .emptyFields: "Completa todos los campos para ingresar."
        case .unknownEmail: "Parece que no tienes acceso a IPB. Comunícate con el administrador."
        case .wrongPassword: "Tu correo no coincide con tu contraseña. Intenta nuevamente."
        case .inactive: "Tu usuario está desactivado. Comunícate con el administrador."
        case .emailTaken: "Ya existe un usuario con ese correo."
        case .weakPassword: "La contraseña debe tener al menos 6 caracteres."
        }
    }
}

/// Current signed-in user. Persists the session so the iPad reopens straight into the app.
@MainActor
@Observable
final class Session {
    private(set) var user: AppUser?
    private let context: NSManagedObjectContext
    private let defaults: UserDefaults
    private static let key = "session.userID"

    init(context: NSManagedObjectContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
        restore()
    }

    var role: Role { user?.role ?? .plantManager }
    var isSignedIn: Bool { user != nil }
    var needsOnboarding: Bool { context.count(AppUser.self) == 0 }

    var service: ProductionService { ProductionService(context: context, author: user?.fullName) }

    func signIn(email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !email.isEmpty, !password.isEmpty else { throw AuthError.emptyFields }
        guard let user = Self.findUser(email: email, in: context) else { throw AuthError.unknownEmail }
        guard PasswordHasher.verify(password, hash: user.passwordHash, salt: user.passwordSalt) else { throw AuthError.wrongPassword }
        guard user.isActive else { throw AuthError.inactive }
        self.user = user
        defaults.set(user.id?.uuidString, forKey: Self.key)
    }

    /// Signs in a freshly created user (onboarding).
    func adopt(_ user: AppUser) {
        self.user = user
        defaults.set(user.id?.uuidString, forKey: Self.key)
    }

    func signOut() {
        user = nil
        defaults.removeObject(forKey: Self.key)
    }

    /// Re-reads the user after edits (e.g. role change) or after a restore.
    func restore() {
        guard let raw = defaults.string(forKey: Self.key), let id = UUID(uuidString: raw) else { user = nil; return }
        let match = context.fetchAll(AppUser.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first
        user = (match?.isActive ?? false) ? match : nil
    }

    nonisolated static func findUser(email: String, in context: NSManagedObjectContext) -> AppUser? {
        context.fetchAll(AppUser.self, predicate: NSPredicate(format: "email ==[c] %@", email)).first
    }

    @discardableResult
    nonisolated static func createUser(
        firstName: String, lastName: String, email: String, phone: String, password: String,
        role: Role, plant: Plant?, avatar: Data?, in context: NSManagedObjectContext
    ) throws -> AppUser {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !firstName.isEmpty, !email.isEmpty else { throw AuthError.emptyFields }
        guard password.count >= 6 else { throw AuthError.weakPassword }
        guard findUser(email: email, in: context) == nil else { throw AuthError.emailTaken }
        let user = AppUser(context: context)
        user.stampCreated()
        user.firstName = firstName
        user.lastName = lastName
        user.email = email
        user.phone = phone
        user.role = role
        user.plant = role == .plantManager ? plant : nil
        user.avatarData = avatar
        user.isActive = true
        setPassword(password, for: user)
        try context.saveIfNeeded()
        return user
    }

    nonisolated static func setPassword(_ password: String, for user: AppUser) {
        let salt = PasswordHasher.makeSalt()
        user.passwordSalt = salt
        user.passwordHash = PasswordHasher.hash(password, salt: salt)
    }
}
