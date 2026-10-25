import SwiftUI

struct SuppliersView: View {
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Supplier.name, ascending: true)])
    private var suppliers: FetchedResults<Supplier>

    @State private var search = ""
    @State private var editor: PartyEditorTarget<Supplier>?
    @State private var pendingDelete: Supplier?

    private var filtered: [Supplier] {
        suppliers.filter { supplier in
            CatalogSearch.matches(
                search, [supplier.name, supplier.address] + supplier.contactList.flatMap { [$0.name, $0.email, $0.role] })
        }
    }

    var body: some View {
        Group {
            if suppliers.isEmpty {
                ContentUnavailableView {
                    Label("Sin proveedores", systemImage: "truck.box")
                } description: {
                    Text("Guarda a tus proveedores de telas, hilos y avíos con sus contactos.")
                } actions: {
                    Button("Nuevo proveedor", systemImage: "plus") { editor = .new }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 60)
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 320), spacing: 18) {
                    ForEach(filtered, id: \.objectID) { supplier in
                        NavigationLink(value: Route.supplier(supplier.objectID)) {
                            SupplierCard(supplier: supplier)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Editar", systemImage: "pencil") { editor = .edit(supplier) }
                            if let url = ContactLinks.mailto(supplier.contactList.compactMap(\.email)) {
                                Link(destination: url) { Label("Enviar correo a todos", systemImage: "envelope") }
                            }
                            Divider()
                            Button("Eliminar", systemImage: "trash", role: .destructive) { pendingDelete = supplier }
                        }
                    }
                }
                .animation(.spring(duration: 0.35), value: filtered.map(\.objectID))
            }
        }
        .catalogScroll()
        .navigationTitle("Proveedores")
        .searchable(text: $search, prompt: "Buscar proveedor, contacto o correo")
        .toolbar { AddToolbarButton(title: "Nuevo proveedor") { editor = .new } }
        .sheet(item: $editor) { target in
            PartyEditorSheet(supplier: target.object, startWithNewContact: target.addingContact)
        }
        .confirmDelete("¿Eliminar \(pendingDelete?.displayName ?? String(localized: "proveedor"))?", item: $pendingDelete) { supplier in
            delete(supplier)
        }
    }

    private func delete(_ supplier: Supplier) {
        let name = supplier.displayName
        do {
            try session.service.delete(supplier)
            toasts.show("Proveedor «\(name)» eliminado")
        } catch {
            toasts.error(error)
        }
    }
}

private struct SupplierCard: View {
    @ObservedObject var supplier: Supplier

    var body: some View {
        let contacts = supplier.contactList
        PartyCard(name: supplier.displayName, address: supplier.address, contacts: contacts, symbol: "truck.box.fill") {
            HStack {
                CardStat(symbol: "person.2.fill", value: Fmt.int(contacts.count), label: "contactos")
                Spacer()
                if let email = contacts.first?.email, let url = ContactLinks.mailto([email]) {
                    Link(destination: url) {
                        Image(systemName: "envelope.fill").frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Enviar correo a \(email)")
                }
                if let phone = contacts.first?.phone, let url = ContactLinks.tel(phone) {
                    Link(destination: url) {
                        Image(systemName: "phone.fill").frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Llamar a \(phone)")
                }
            }
        }
    }
}

#Preview("Proveedores") {
    NavigationStack { SuppliersView() }
        .catalogPreviewEnvironment()
}
