import CoreData
import Foundation

/// Applies server changes to Core Data by id: upsert, or delete for tombstones.
/// Conflicts are last-writer-wins on `updatedAt`: a record with a newer pending local change
/// (outbox) is kept, and will be pushed; otherwise the server copy wins and the pending entry is dropped.
/// Saves without tracking, so applied changes never echo back into the outbox.
enum SyncApplier {
    struct Result: Equatable {
        var upserted = 0
        var deleted = 0
        /// Changes skipped because a newer local edit is waiting to be pushed.
        var keptLocal = 0
        /// Deletes skipped because the record still has dependents here (Deny rules).
        var blocked = 0
    }

    @discardableResult
    static func apply(_ changes: [ServerChange], in context: NSManagedObjectContext) throws -> Result {
        var result = Result()
        var cache: [String: [UUID: NSManagedObject]] = [:]

        func find(_ entityName: String, _ id: UUID) -> NSManagedObject? {
            if let hit = cache[entityName]?[id], !hit.isDeleted { return hit }
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let object = (try? context.fetch(request))?.first, !object.isDeleted else { return nil }
            cache[entityName, default: [:]][id] = object
            return object
        }

        /// True when a pending local change is newer than the server's copy (local wins).
        func localWins(_ entity: SyncEntity, _ change: ServerChange) -> Bool {
            guard let pending = SyncOutbox.entry(entity, id: change.id, in: context) else { return false }
            if let changedAt = pending.changedAt, changedAt > change.updatedAt { return true }
            context.delete(pending)
            return false
        }

        let known = changes.filter { $0.entity != nil }
        let upserts = known.filter { !$0.deleted && $0.data != nil }.sorted { $0.entity!.order < $1.entity!.order }
        let deletes = known.filter(\.deleted).sorted { $0.entity!.order > $1.entity!.order }

        for change in upserts {
            guard let entity = change.entity, let payload = change.data, payload.entity == entity else { continue }
            if localWins(entity, change) {
                result.keptLocal += 1
                continue
            }
            let object = find(entity.entityName, change.id) ?? adoptByEmail(change, payload, in: context) ?? {
                let created = NSEntityDescription.insertNewObject(forEntityName: entity.entityName, into: context)
                return created
            }()
            object.setValue(change.id, forKey: "id")
            cache[entity.entityName, default: [:]][change.id] = object
            payload.apply(to: object, lookup: find)
            result.upserted += 1
        }

        for change in deletes {
            guard let entity = change.entity else { continue }
            if localWins(entity, change) {
                result.keptLocal += 1
                continue
            }
            guard let object = find(entity.entityName, change.id) else { continue }
            if hasLiveDependents(object) {
                result.blocked += 1
                continue
            }
            context.delete(object)
            context.processPendingChanges()  // cascades now, so later Deny checks see them
            result.deleted += 1
        }

        try context.saveIfNeeded()
        return result
    }

    /// A user created offline on another device (or the local admin of an iPad that joins a
    /// licence) has a different id but the same email: adopt the server id instead of duplicating.
    private static func adoptByEmail(_ change: ServerChange, _ payload: RecordPayload, in context: NSManagedObjectContext) -> NSManagedObject? {
        guard case .user(let dto) = payload, let email = dto.email, let local = Session.findUser(email: email, in: context) else { return nil }
        if let id = local.id, let pending = SyncOutbox.entry(.users, id: id, in: context) { context.delete(pending) }
        return local
    }

    /// Mirrors the Deny delete rules: a plant with assignments or a client with orders stays.
    private static func hasLiveDependents(_ object: NSManagedObject) -> Bool {
        for relationship in object.entity.relationshipsByName.values where relationship.deleteRule == .denyDeleteRule {
            if let set = object.value(forKey: relationship.name) as? Set<NSManagedObject>, set.contains(where: { !$0.isDeleted }) {
                return true
            }
        }
        return false
    }
}
