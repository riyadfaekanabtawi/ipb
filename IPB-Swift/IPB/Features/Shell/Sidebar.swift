import SwiftUI

struct Sidebar: View {
    @Environment(Session.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(sortDescriptors: []) private var orders: FetchedResults<CutOrder>
    @FetchRequest(sortDescriptors: []) private var assignments: FetchedResults<Assignment>
    @AppStorage("settings.urgencyWindowDays") private var urgencyWindow = 7

    var body: some View {
        @Bindable var router = router
        List(selection: $router.selection) {
            ForEach(AppSection.Group.allCases, id: \.self) { group in
                let items = session.role.sections.filter { $0.group == group }
                if !items.isEmpty {
                    Section(group.rawValue) {
                        ForEach(items) { section in
                            NavigationLink(value: section) {
                                Label {
                                    Text(section.title)
                                } icon: {
                                    Image(systemName: section.symbol).foregroundStyle(Theme.brand)
                                }
                                .badge(badge(for: section))
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("IPB")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.isCommandPalettePresented = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Buscar (⌘K)")
            }
        }
        .safeAreaInset(edge: .bottom) { UserFooter() }
    }

    private func badge(for section: AppSection) -> Int {
        switch section {
        case .orders: orders.filter { $0.remainingQuantity > 0 }.count
        case .shipments: assignments.filter { $0.isUrgent(windowDays: urgencyWindow) }.count
        default: 0
        }
    }
}

private struct UserFooter: View {
    @Environment(Session.self) private var session
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Environment(AppRouter.self) private var router
    @State private var confirmSignOut = false

    var body: some View {
        if let user = session.user {
            HStack(spacing: 12) {
                AvatarView(name: user.fullName, imageData: user.avatarData, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectivity.isOnline ? Theme.success : Theme.warning)
                            .frame(width: 7, height: 7)
                        Text(user.role.title)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Label(
                        connectivity.isOnline ? "En línea" : "Sin conexión — todo se guarda localmente",
                        systemImage: connectivity.isOnline ? "wifi" : "wifi.slash")
                    Divider()
                    Button("Ajustes", systemImage: "gearshape") { router.open(.settings) }
                    Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        confirmSignOut = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.brand)
                }
                .accessibilityLabel("Opciones de usuario")
            }
            .padding(14)
            .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
            .padding(12)
            .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmSignOut) {
                Button("Cerrar sesión", role: .destructive) { session.signOut() }
            }
        }
    }
}
