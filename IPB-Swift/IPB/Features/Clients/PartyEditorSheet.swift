import CoreData
import SwiftUI

/// Create/edit sheet shared by clients and suppliers: name, address and any number of contacts.
struct PartyEditorSheet: View {
    enum Kind {
        case client, supplier

        var noun: String { self == .client ? "cliente" : "proveedor" }
    }

    var kind: Kind
    var client: Client?
    var supplier: Supplier?
    /// Opens straight into a fresh contact row (from "Agregar contacto" on a detail screen).
    var startWithNewContact = false

    @Environment(\.managedObjectContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var contacts: [ContactDraft] = []
    @State private var loaded = false
    @FocusState private var nameFocused: Bool

    init(client: Client?, startWithNewContact: Bool = false) {
        kind = .client
        self.client = client
        self.startWithNewContact = startWithNewContact
    }

    init(supplier: Supplier?, startWithNewContact: Bool = false) {
        kind = .supplier
        self.supplier = supplier
        self.startWithNewContact = startWithNewContact
    }

    private var isNew: Bool { client == nil && supplier == nil }

    var body: some View {
        FormSheet(
            title: isNew ? "Nuevo \(kind.noun)" : "Editar \(kind.noun)",
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
            onSave: save
        ) {
            Section("Datos generales") {
                TextField("Nombre", text: $name)
                    .focused($nameFocused)
                    .font(.headline)
                TextField("Dirección", text: $address, axis: .vertical)
                    .lineLimit(1...3)
                    .textContentType(.fullStreetAddress)
            }
            ContactsEditorSection(contacts: $contacts)
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch kind {
        case .client:
            name = client?.name ?? ""
            address = client?.address ?? ""
            contacts = client?.contactList.map(ContactDraft.init) ?? []
        case .supplier:
            name = supplier?.name ?? ""
            address = supplier?.address ?? ""
            contacts = supplier?.contactList.map(ContactDraft.init) ?? []
        }
        if isNew || startWithNewContact || contacts.isEmpty { contacts.append(ContactDraft()) }
        if isNew { nameFocused = true }
    }

    private func save() {
        let service = CatalogService(context: context)
        do {
            switch kind {
            case .client:
                let saved = try service.saveClient(client, name: name, address: address, contacts: contacts)
                toasts.show(isNew ? "Cliente «\(saved.displayName)» creado" : "Cliente actualizado")
            case .supplier:
                let saved = try service.saveSupplier(supplier, name: name, address: address, contacts: contacts)
                toasts.show(isNew ? "Proveedor «\(saved.displayName)» creado" : "Proveedor actualizado")
            }
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

/// Sheet target for client/supplier editors.
enum PartyEditorTarget<Object: NSManagedObject>: Identifiable {
    case new
    case edit(Object, addingContact: Bool = false)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let object, let adding): object.objectID.uriRepresentation().absoluteString + (adding ? "+" : "")
        }
    }

    var object: Object? {
        if case .edit(let object, _) = self { return object }
        return nil
    }

    var addingContact: Bool {
        if case .edit(_, let adding) = self { return adding }
        return false
    }
}

/// Card used by both the clients and the suppliers grids.
struct PartyCard<Footer: View>: View {
    var name: String
    var address: String?
    var contacts: [Contact]
    var symbol: String
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AvatarView(name: name, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.title3.weight(.bold)).lineLimit(1)
                    Label(address ?? "Sin dirección", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            PrimaryContactLine(contacts: contacts)
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(.rect)
    }
}

/// Opens an address in Apple Maps.
enum MapsLink {
    static func url(for address: String?) -> URL? {
        guard let address, !address.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: address)]
        return components?.url
    }
}
