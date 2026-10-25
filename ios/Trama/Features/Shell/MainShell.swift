import CoreData
import SwiftUI

/// Sidebar + detail split view. Sections are filtered by the signed-in user's role.
struct MainShell: View {
    @Environment(Session.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var router = router
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 320)
        } detail: {
            if let section = router.selection, session.role.sections.contains(section) {
                NavigationStack(path: router.path(for: section)) {
                    SectionScreen(section: section)
                        .navigationDestination(for: Route.self) { route in
                            RouteScreen(route: route)
                        }
                }
                .id(section)
            } else {
                ContentUnavailableView("Selecciona una sección", systemImage: "sidebar.left")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .safeAreaInset(edge: .top, spacing: 0) { SyncBanner() }
        .onAppear {
            if router.selection == nil || !session.role.sections.contains(router.selection!) {
                router.selection = session.role.landing
            }
        }
        .sheet(isPresented: $router.isCommandPalettePresented) {
            CommandPalette()
                .presentationDetents([.large])
        }
        .background {
            // Hidden buttons give hardware-keyboard shortcuts for every visible section.
            ForEach(Array(session.role.sections.prefix(9).enumerated()), id: \.element) { index, section in
                Button(section.title) { router.open(section) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .hidden()
            }
            Button("Buscar") { router.isCommandPalettePresented = true }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
        }
    }
}

/// Maps a section to its root screen.
struct SectionScreen: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .dashboard: DashboardView()
        case .orders: OrdersView()
        case .board: CutBoardView()
        case .production: ProductionReportsView()
        case .shipments: UrgentShipmentsView()
        case .calendar: PlantCalendarView()
        case .plants: PlantsView()
        case .clients: ClientsView()
        case .suppliers: SuppliersView()
        case .styles: StylesView()
        case .projects: ProjectsView()
        case .users: UsersView()
        case .calculator: CalculatorView()
        case .settings: SettingsView()
        }
    }
}

/// Resolves pushed routes to screens, guarding against deleted objects.
struct RouteScreen: View {
    let route: Route
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        switch route {
        case .assignment(let id):
            if let object = context.existing(Assignment.self, id) { AssignmentDetailView(assignment: object) } else { missing }
        case .order(let id):
            if let object = context.existing(CutOrder.self, id) { OrderDetailView(order: object) } else { missing }
        case .plant(let id):
            if let object = context.existing(Plant.self, id) { PlantDetailView(plant: object) } else { missing }
        case .client(let id):
            if let object = context.existing(Client.self, id) { ClientDetailView(client: object) } else { missing }
        case .supplier(let id):
            if let object = context.existing(Supplier.self, id) { SupplierDetailView(supplier: object) } else { missing }
        case .style(let id):
            if let object = context.existing(Style.self, id) { StyleDetailView(style: object) } else { missing }
        }
    }

    private var missing: some View {
        ContentUnavailableView("Este elemento ya no existe", systemImage: "questionmark.folder")
    }
}

extension NSManagedObjectContext {
    /// Returns the live object for an ID, or nil if it was deleted.
    func existing<T: NSManagedObject>(_ type: T.Type, _ id: NSManagedObjectID) -> T? {
        guard let object = try? existingObject(with: id) as? T, !object.isDeleted else { return nil }
        return object
    }
}
