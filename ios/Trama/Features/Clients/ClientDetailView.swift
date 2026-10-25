import SwiftUI

struct ClientDetailView: View {
    @ObservedObject var client: Client

    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var editor: PartyEditorTarget<Client>?
    @State private var confirmingDelete = false

    var body: some View {
        let orders = client.orderList
        let projects = client.sortedProjects

        VStack(alignment: .leading, spacing: 28) {
            DetailHero(client.displayName, subtitle: client.address ?? String(localized: "Sin dirección")) {
                AvatarView(name: client.displayName, size: 72)
            } trailing: {
                HStack(spacing: 10) {
                    HeroStat(value: Fmt.int(orders.count), label: "Cortes")
                    HeroStat(value: Fmt.int(orders.reduce(0) { $0 + Int($1.quantity) }), label: "Prendas")
                    HeroStat(value: Fmt.money(orders.reduce(0) { $0 + $1.revenue }, compact: true), label: "Valor")
                }
            }

            ContactsSection(contacts: client.contactList) { editor = .edit(client, addingContact: true) }

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("Cortes", subtitle: orders.isEmpty ? "Sin cortes" : "\(orders.count) cortes")
                if orders.isEmpty {
                    Text("Este cliente aún no tiene cortes.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .card()
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(orders, id: \.objectID) { order in
                            NavigationLink(value: Route.order(order.objectID)) {
                                ClientOrderRow(order: order)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !projects.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("Proyectos", subtitle: "\(projects.count) cotizaciones") {
                        Button("Ver todos", systemImage: "arrow.up.right") { router.open(.projects) }
                            .buttonStyle(.borderless)
                    }
                    LazyVGrid(columns: AdaptiveGrid.adaptive(min: 260, spacing: 14), spacing: 14) {
                        ForEach(projects, id: \.objectID) { project in
                            ClientProjectTile(project: project)
                        }
                    }
                }
            }
        }
        .catalogScroll()
        .navigationTitle(client.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Editar", systemImage: "pencil") { editor = .edit(client) }
                    .keyboardShortcut("e", modifiers: .command)
                Menu {
                    if let url = MapsLink.url(for: client.address) {
                        Link(destination: url) { Label("Abrir en Mapas", systemImage: "map") }
                    }
                    Button("Eliminar cliente", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Más opciones")
            }
        }
        .sheet(item: $editor) { target in
            PartyEditorSheet(client: target.object, startWithNewContact: target.addingContact)
        }
        .confirmDelete(
            "¿Eliminar \(client.displayName)?", isPresented: $confirmingDelete,
            message: "Solo se pueden eliminar clientes sin cortes.", action: delete)
    }

    private func delete() {
        let name = client.displayName
        do {
            try session.service.delete(client)
            toasts.show("Cliente «\(name)» eliminado")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

private struct ClientOrderRow: View {
    @ObservedObject var order: CutOrder

    var body: some View {
        let state = order.assignmentState
        CatalogRowCard {
            SwatchImage(data: order.style?.imageData, name: order.styleName, cornerRadius: 10)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(order.displayCode).font(.headline)
                Text([order.list.map { String(localized: "Lista \($0)") }, order.garment].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 22) {
                    figure(Fmt.int(Int(order.quantity)), "prendas")
                    figure(Fmt.money(order.revenue, compact: true), "valor")
                    Pill(text: state.title, symbol: nil, tint: state.tint)
                }
                Pill(text: state.title, symbol: nil, tint: state.tint)
            }
        }
    }

    private func figure(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct ClientProjectTile: View {
    @ObservedObject var project: Project

    var body: some View {
        HStack(spacing: 12) {
            SwatchImage(data: project.photoData, name: project.fabric ?? project.displayClient, cornerRadius: 12)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.money(project.total)).font(.headline).monospacedDigit()
                Text("\(Int(project.quantity)) prendas · \(project.fabric ?? String(localized: "Sin tela"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Pill(text: project.status.title, symbol: project.status.symbol, tint: project.status.tint)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }
}

extension Client {
    var sortedProjects: [Project] {
        (projects as? Set<Project> ?? []).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
}

#Preview("Detalle de cliente") {
    NavigationStack { ClientDetailView(client: CatalogPreviewData.first(Client.self)) }
        .catalogPreviewEnvironment()
}
