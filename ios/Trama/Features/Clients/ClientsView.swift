import SwiftUI

struct ClientsView: View {
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Client.name, ascending: true)])
    private var clients: FetchedResults<Client>

    @State private var search = ""
    @State private var editor: PartyEditorTarget<Client>?
    @State private var pendingDelete: Client?

    private var filtered: [Client] {
        clients.filter { client in
            CatalogSearch.matches(
                search, [client.name, client.address] + client.contactList.flatMap { [$0.name, $0.email, $0.role] })
        }
    }

    var body: some View {
        Group {
            if clients.isEmpty {
                ContentUnavailableView {
                    Label("Sin clientes", systemImage: "person.2")
                } description: {
                    Text("Registra a tus clientes para asignarles cortes y proyectos.")
                } actions: {
                    Button("Nuevo cliente", systemImage: "plus") { editor = .new }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 60)
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 320), spacing: 18) {
                    ForEach(filtered, id: \.objectID) { client in
                        NavigationLink(value: Route.client(client.objectID)) {
                            ClientCard(client: client)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: client) }
                    }
                }
                .animation(.spring(duration: 0.35), value: filtered.map(\.objectID))
            }
        }
        .catalogScroll()
        .navigationTitle("Clientes")
        .searchable(text: $search, prompt: "Buscar cliente, contacto o correo")
        .toolbar { AddToolbarButton(title: "Nuevo cliente") { editor = .new } }
        .sheet(item: $editor) { target in
            PartyEditorSheet(client: target.object, startWithNewContact: target.addingContact)
        }
        .confirmDelete(
            "¿Eliminar \(pendingDelete?.displayName ?? "cliente")?", item: $pendingDelete,
            message: "Solo se pueden eliminar clientes sin cortes. Sus proyectos conservarán el nombre."
        ) { client in
            delete(client)
        }
    }

    @ViewBuilder
    private func menu(for client: Client) -> some View {
        Button("Editar", systemImage: "pencil") { editor = .edit(client) }
        if let url = ContactLinks.mailto(client.contactList.compactMap(\.email)) {
            Link(destination: url) { Label("Enviar correo a todos", systemImage: "envelope") }
        }
        Divider()
        Button("Eliminar", systemImage: "trash", role: .destructive) { pendingDelete = client }
    }

    private func delete(_ client: Client) {
        let name = client.displayName
        do {
            try session.service.delete(client)
            toasts.show("Cliente «\(name)» eliminado")
        } catch {
            toasts.error(error)
        }
    }
}

private struct ClientCard: View {
    @ObservedObject var client: Client

    var body: some View {
        let orders = client.orderList
        let revenue = orders.reduce(0) { $0 + $1.revenue }
        let projects = (client.projects as? Set<Project>)?.count ?? 0
        PartyCard(name: client.displayName, address: client.address, contacts: client.contactList, symbol: "person.2.fill") {
            HStack {
                CardStat(symbol: "scissors", value: Fmt.int(orders.count), label: "cortes")
                Spacer()
                CardStat(symbol: "folder.fill", value: Fmt.int(projects), label: "proyectos", tint: Theme.info)
                Spacer()
                CardStat(symbol: "banknote", value: Fmt.money(revenue, compact: true), label: "valor", tint: Theme.success)
            }
        }
    }
}

#Preview("Clientes") {
    NavigationStack { ClientsView() }
        .catalogPreviewEnvironment()
}
