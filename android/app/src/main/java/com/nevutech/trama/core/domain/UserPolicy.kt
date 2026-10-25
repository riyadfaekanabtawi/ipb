package com.nevutech.trama.core.domain

/**
 * Keeps the user catalog administrable: an admin can't lock themselves out, and there is always
 * at least one active admin left.
 */
object UserPolicy {
    data class Member(val id: String, val role: Role, val isActive: Boolean)

    sealed interface Change {
        data object Delete : Change
        data object Deactivate : Change
        data class ChangeRole(val role: Role) : Change
    }

    enum class Violation(val message: String) {
        CannotDeleteSelf("No puedes eliminar tu propio usuario."),
        CannotDeactivateSelf("No puedes desactivar tu propio usuario."),
        CannotChangeOwnRole("No puedes cambiar tu propio puesto."),
        LastAdmin("Debe quedar al menos un administrador activo."),
    }

    /** Returns the rule a change would break, or null when it is allowed. */
    fun violation(change: Change, target: Member, actingUserId: String?, members: List<Member>): Violation? {
        val isSelf = target.id == actingUserId
        when {
            change is Change.Delete && isSelf -> return Violation.CannotDeleteSelf
            change is Change.Deactivate && isSelf -> return Violation.CannotDeactivateSelf
            change is Change.ChangeRole && isSelf && change.role != target.role -> return Violation.CannotChangeOwnRole
        }
        // Simulate the change and make sure an active admin survives it.
        val after = members.mapNotNull { member ->
            if (member.id != target.id) return@mapNotNull member
            when (change) {
                Change.Delete -> null
                Change.Deactivate -> member.copy(isActive = false)
                is Change.ChangeRole -> member.copy(role = change.role)
            }
        }
        val hadAdmin = members.any { it.role == Role.Admin && it.isActive }
        val hasAdmin = after.any { it.role == Role.Admin && it.isActive }
        return if (hadAdmin && !hasAdmin) Violation.LastAdmin else null
    }
}
