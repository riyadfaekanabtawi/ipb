import CoreData
import SwiftUI

@main
struct TramaApp: App {
    private let persistence: PersistenceController
    @State private var session: Session
    @State private var connectivity = ConnectivityMonitor()
    @State private var toasts = ToastCenter()
    @State private var router: AppRouter

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uiTestDemo")
        let persistence = isUITest ? PersistenceController(inMemory: true) : PersistenceController.shared
        if isUITest {
            DemoSeeder.seed(into: persistence.viewContext)
            UserDefaults.standard.set(true, forKey: "demo.seeded")
            UserDefaults.standard.set("Textiles Demo", forKey: Brand.companyKey)
        }
        self.persistence = persistence
        let session = Session(context: persistence.viewContext)
        let router = AppRouter()
        #if DEBUG
            if isUITest { Self.applyDebugLaunchArguments(session: session, router: router, context: persistence.viewContext) }
        #endif
        _session = State(initialValue: session)
        _router = State(initialValue: router)
    }

    #if DEBUG
        /// Demo-mode shortcuts for screenshots and manual QA:
        /// `-loginAs admin@demo.local -openSection board -openRoute firstAssignment|firstOrder`.
        private static func applyDebugLaunchArguments(session: Session, router: AppRouter, context: NSManagedObjectContext) {
            let defaults = UserDefaults.standard
            if let email = defaults.string(forKey: "loginAs") {
                try? session.signIn(email: email, password: DemoSeeder.demoPassword)
            }
            if let raw = defaults.string(forKey: "openSection"), let section = AppSection(rawValue: raw) {
                router.selection = section
                switch defaults.string(forKey: "openRoute") {
                case "firstAssignment":
                    if let a = context.fetchAll(Assignment.self, sort: [NSSortDescriptor(key: "scheduledDate", ascending: true)]).first {
                        router.open(section, pushing: Route.assignment(a.objectID))
                    }
                case "firstOrder":
                    if let o = context.fetchAll(CutOrder.self, sort: [NSSortDescriptor(key: "code", ascending: true)]).first {
                        router.open(section, pushing: Route.order(o.objectID))
                    }
                default: break
                }
            }
        }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .environment(session)
                .environment(connectivity)
                .environment(toasts)
                .environment(router)
                .environment(\.persistence, persistence)
                .tint(Theme.brand)
        }
    }
}

private struct PersistenceKey: EnvironmentKey {
    static let defaultValue: PersistenceController = .shared
}

extension EnvironmentValues {
    var persistence: PersistenceController {
        get { self[PersistenceKey.self] }
        set { self[PersistenceKey.self] = newValue }
    }
}
