import CoreData
import SwiftUI

@main
struct IPBApp: App {
    private let persistence: PersistenceController
    @State private var session: Session
    @State private var connectivity = ConnectivityMonitor()
    @State private var toasts = ToastCenter()
    @State private var router = AppRouter()

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uiTestDemo")
        let persistence = isUITest ? PersistenceController(inMemory: true) : PersistenceController.shared
        if isUITest {
            DemoSeeder.seed(into: persistence.viewContext)
            UserDefaults.standard.set(true, forKey: "demo.seeded")
        }
        self.persistence = persistence
        _session = State(initialValue: Session(context: persistence.viewContext))
    }

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
