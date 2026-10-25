import Foundation

/// Rules that keep the user catalog administrable: an admin can't lock themselves out,
/// and there is always at least one active admin left to manage the app.
enum UserPolicy {
    /// Minimal, Core Data–free view of a user for rule checks.
    struct Member: Equatable {
        var id: UUID
        var role: Role
        var isActive: Bool
    }

    enum Change: Equatable {
        case delete
        case deactivate
        case changeRole(Role)
    }

    enum Violation: LocalizedError, Equatable {
        case cannotDeleteSelf
        case cannotDeactivateSelf
        case cannotChangeOwnRole
        case lastAdmin

        var errorDescription: String? {
            switch self {
            case .cannotDeleteSelf: String(localized: "No puedes eliminar tu propio usuario.")
            case .cannotDeactivateSelf: String(localized: "No puedes desactivar tu propio usuario.")
            case .cannotChangeOwnRole: String(localized: "No puedes cambiar tu propio puesto.")
            case .lastAdmin: String(localized: "Debe quedar al menos un administrador activo.")
            }
        }
    }

    /// Returns the rule a change would break, or nil when it is allowed.
    static func violation(of change: Change, on target: Member, actingUserID: UUID?, members: [Member]) -> Violation? {
        let isSelf = target.id == actingUserID
        switch change {
        case .delete where isSelf: return .cannotDeleteSelf
        case .deactivate where isSelf: return .cannotDeactivateSelf
        case .changeRole(let role) where isSelf && role != target.role: return .cannotChangeOwnRole
        default: break
        }

        // Simulate the change and make sure an active admin survives it.
        let after: [Member] = members.compactMap { member in
            guard member.id == target.id else { return member }
            switch change {
            case .delete: return nil
            case .deactivate: return Member(id: member.id, role: member.role, isActive: false)
            case .changeRole(let role): return Member(id: member.id, role: role, isActive: member.isActive)
            }
        }
        let hadAdmin = members.contains { $0.role == .admin && $0.isActive }
        let hasAdmin = after.contains { $0.role == .admin && $0.isActive }
        return hadAdmin && !hasAdmin ? .lastAdmin : nil
    }
}
