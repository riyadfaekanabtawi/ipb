import CoreData
import Foundation

extension Notification.Name {
    /// Posted after a tracked save added entries to the outbox (drives the debounced push).
    static let syncOutboxChanged = Notification.Name("trama.syncOutboxChanged")
}

enum SyncWriteError: LocalizedError, Equatable {
    case readOnly

    var errorDescription: String? {
        switch self {
        case .readOnly: "Tu licencia está vencida o suspendida: los datos son de solo lectura. Contacta a soporte para renovarla."
        }
    }
}

extension NSManagedObjectContext {
    private static let trackingKey = "trama.sync.tracking"
    private static let readOnlyKey = "trama.sync.readOnly"

    /// True while the iPad is linked to a licence: service writes are recorded in the outbox.
    /// Stored per context, so local-only mode (and tests) never touch the outbox.
    var isSyncTracking: Bool {
        get { userInfo[Self.trackingKey] as? Bool ?? false }
        set { userInfo[Self.trackingKey] = newValue }
    }

    /// True when the licence is not writable (expired / suspended): tracked saves are refused.
    var isSyncReadOnly: Bool {
        get { userInfo[Self.readOnlyKey] as? Bool ?? false }
        set { userInfo[Self.readOnlyKey] = newValue }
    }

    /// Save used by the write services (ProductionService, CatalogService, Session). When sync is
    /// on, every changed record is stamped and queued in the outbox in the same transaction.
    func saveTracked(now: Date = .now) throws {
        guard isSyncTracking else { return try saveIfNeeded() }
        processPendingChanges()
        guard hasChanges else { return }
        if isSyncReadOnly {
            rollback()
            throw SyncWriteError.readOnly
        }
        let queued = SyncOutbox.recordPendingChanges(in: self, now: now)
        try save()
        if queued > 0 { NotificationCenter.default.post(name: .syncOutboxChanged, object: self) }
    }
}

/// Local changes waiting to be pushed: one `SyncOutboxEntry` per record (coalesced), with
/// `tombstone` for deletes. Entries leave the outbox once the server applied or answered them.
enum SyncOutbox {
    /// Queues the context's pending inserts, updates and deletes. Returns how many records were queued.
    @discardableResult
    static func recordPendingChanges(in context: NSManagedObjectContext, now: Date = .now) -> Int {
        var count = 0
        for object in context.insertedObjects.union(context.updatedObjects) where !object.isDeleted {
            guard SyncEntity(object: object) != nil else { continue }
            if !object.isInserted, !hasSyncedChanges(object) { continue }
            if object.value(forKey: "id") == nil { object.setValue(UUID(), forKey: "id") }
            if let stamped = object as? Timestamped {
                if stamped.createdAt == nil { stamped.createdAt = now }
                stamped.updatedAt = now
            }
            enqueue(object, tombstone: false, at: now, in: context)
            count += 1
        }
        for object in context.deletedObjects {
            guard SyncEntity(object: object) != nil, object.value(forKey: "id") is UUID else { continue }
            enqueue(object, tombstone: true, at: now, in: context)
            count += 1
        }
        return count
    }

    /// Queues every syncable record (initial upload of an iPad's existing data).
    @discardableResult
    static func enqueueAll(in context: NSManagedObjectContext, now: Date = .now) throws -> Int {
        var count = 0
        for entity in SyncEntity.allCases {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity.entityName)
            for object in try context.fetch(request) {
                if object.value(forKey: "id") == nil { object.setValue(UUID(), forKey: "id") }
                let changedAt = (object as? Timestamped)?.updatedAt ?? now
                upsert(entity, id: object.value(forKey: "id") as! UUID, tombstone: false, at: changedAt, in: context)
                count += 1
            }
        }
        try context.saveIfNeeded()
        return count
    }

    static func entries(in context: NSManagedObjectContext) -> [SyncOutboxEntry] {
        context.fetchAll(SyncOutboxEntry.self).sorted {
            let l = SyncEntity(rawValue: $0.entityName ?? "")?.order ?? 0
            let r = SyncEntity(rawValue: $1.entityName ?? "")?.order ?? 0
            return l != r ? l < r : ($0.changedAt ?? .distantPast) < ($1.changedAt ?? .distantPast)
        }
    }

    static func entry(_ entity: SyncEntity, id: UUID, in context: NSManagedObjectContext) -> SyncOutboxEntry? {
        context.fetchAll(
            SyncOutboxEntry.self,
            predicate: NSPredicate(format: "entityName == %@ AND recordID == %@", entity.rawValue, id as CVarArg)
        ).first
    }

    static func count(in context: NSManagedObjectContext) -> Int { context.count(SyncOutboxEntry.self) }

    static func clear(in context: NSManagedObjectContext) throws {
        for entry in context.fetchAll(SyncOutboxEntry.self) { context.delete(entry) }
        try context.saveIfNeeded()
    }

    // MARK: Private

    /// Ignores updates that only touched to-many relationships (inverse bookkeeping): those don't
    /// change the record's DTO.
    private static func hasSyncedChanges(_ object: NSManagedObject) -> Bool {
        let relationships = object.entity.relationshipsByName
        return object.changedValues().keys.contains { key in
            guard let relationship = relationships[key] else { return true }
            return !relationship.isToMany
        }
    }

    private static func enqueue(_ object: NSManagedObject, tombstone: Bool, at date: Date, in context: NSManagedObjectContext) {
        guard let entity = SyncEntity(object: object), let id = object.value(forKey: "id") as? UUID else { return }
        upsert(entity, id: id, tombstone: tombstone, at: date, in: context)
    }

    private static func upsert(_ entity: SyncEntity, id: UUID, tombstone: Bool, at date: Date, in context: NSManagedObjectContext) {
        let target = entry(entity, id: id, in: context) ?? SyncOutboxEntry(context: context)
        target.entityName = entity.rawValue
        target.recordID = id
        target.tombstone = tombstone
        target.changedAt = date
    }
}
