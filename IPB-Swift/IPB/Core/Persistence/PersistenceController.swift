import CoreData
import OSLog

/// Owns the Core Data stack. The local SQLite store is the source of truth: the app works
/// fully offline, and optional sync layers only import into / export from this store.
final class PersistenceController {
    static let shared = PersistenceController()

    /// In-memory stack for previews and tests, seeded with demo data.
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        DemoSeeder.seed(into: controller.container.viewContext)
        return controller
    }()

    let container: NSPersistentContainer
    private let log = Logger(subsystem: "com.nevutech.ipb", category: "persistence")

    /// Loaded once and shared so multiple in-memory containers (tests) don't register duplicate entity classes.
    static let model: NSManagedObjectModel = {
        guard
            let url = Bundle.main.url(forResource: "IPB", withExtension: "momd")
                ?? Bundle(for: PersistenceController.self).url(forResource: "IPB", withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: url)
        else { fatalError("IPB.momd missing from bundle") }
        return model
    }()

    init(inMemory: Bool = false, storeURL: URL? = nil) {
        container = NSPersistentContainer(name: "IPB", managedObjectModel: Self.model)
        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else if let storeURL {
            description.url = storeURL
        }
        // Lightweight migration keeps future model versions painless.
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { [log] _, error in
            if let error {
                log.fault("Failed to load store: \(error.localizedDescription, privacy: .public)")
                fatalError("Unresolved Core Data error \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.name = "viewContext"
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Wipes every entity. Used by backup restore and "reset demo data".
    func eraseAll() throws {
        let context = viewContext
        // Batch deletes silently skip rows protected by a Deny rule (plants with assignments,
        // clients with orders), so entities that deny deletion go last, after their dependents.
        let ordered = Self.model.entities.sorted { lhs, rhs in
            func denies(_ e: NSEntityDescription) -> Int { e.relationshipsByName.values.filter { $0.deleteRule == .denyDeleteRule }.count }
            return denies(lhs) < denies(rhs)
        }
        for entity in ordered {
            guard let name = entity.name else { continue }
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            delete.resultType = .resultTypeObjectIDs
            if let result = try context.execute(delete) as? NSBatchDeleteResult,
                let ids = result.result as? [NSManagedObjectID]
            {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [context])
            }
        }
        context.reset()
        // Batch deletes never remove Deny-protected entities (and do not throw), so sweep the
        // remainder object by object; their dependents are gone by now.
        var leftovers = false
        for entity in ordered {
            guard let name = entity.name else { continue }
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            request.includesPropertyValues = false
            for object in try context.fetch(request) {
                context.delete(object)
                leftovers = true
            }
        }
        if leftovers {
            try context.save()
            context.reset()
        }
    }
}

extension NSManagedObjectContext {
    /// Saves if there are changes; surfaces errors to the caller.
    func saveIfNeeded() throws {
        guard hasChanges else { return }
        try save()
    }

    func count<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil) -> Int {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        return (try? count(for: request)) ?? 0
    }

    func fetchAll<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil, sort: [NSSortDescriptor] = []) -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        request.sortDescriptors = sort
        return (try? fetch(request)) ?? []
    }
}
