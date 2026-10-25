import SwiftUI

struct SupplierDetailView: View {
    @ObservedObject var supplier: Supplier

    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var editor: PartyEditorTarget<Supplier>?
    @State private var confirmingDelete = false

    var body: some View {
        let contacts = supplier.contactList

        VStack(alignment: .leading, spacing: 28) {
            DetailHero(supplier.displayName, subtitle: supplier.address ?? "Sin dirección") {
                AvatarView(name: supplier.displayName, size: 72, symbol: "truck.box.fill")
            } trailing: {
                HStack(spacing: 10) {
                    HeroStat(value: Fmt.int(contacts.count), label: contacts.count == 1 ? "Contacto" : "Contactos")
                    if let url = MapsLink.url(for: supplier.address) {
                        Link(destination: url) {
                            Label("Mapas", systemImage: "map.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .background(.white.opacity(0.12), in: .rect(cornerRadius: Theme.smallRadius, style: .continuous))
                        }
                        .accessibilityLabel("Abrir dirección en Mapas")
                    }
                }
            }

            ContactsSection(contacts: contacts) { editor = .edit(supplier, addingContact: true) }
        }
        .catalogScroll()
        .navigationTitle(supplier.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Editar", systemImage: "pencil") { editor = .edit(supplier) }
                    .keyboardShortcut("e", modifiers: .command)
                Menu {
                    Button("Eliminar proveedor", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Más opciones")
            }
        }
        .sheet(item: $editor) { target in
            PartyEditorSheet(supplier: target.object, startWithNewContact: target.addingContact)
        }
        .confirmDelete("¿Eliminar \(supplier.displayName)?", isPresented: $confirmingDelete, action: delete)
    }

    private func delete() {
        let name = supplier.displayName
        do {
            try session.service.delete(supplier)
            toasts.show("Proveedor «\(name)» eliminado")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

#Preview("Detalle de proveedor") {
    NavigationStack { SupplierDetailView(supplier: CatalogPreviewData.first(Supplier.self)) }
        .catalogPreviewEnvironment()
}
