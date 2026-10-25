import SwiftUI

/// Form section that edits any number of contacts (legacy had three fixed slots).
/// Rows can be added, removed (swipe or menu) and reordered (drag or menu).
struct ContactsEditorSection: View {
    @Binding var contacts: [ContactDraft]
    @FocusState private var focusedID: ContactDraft.ID?

    var body: some View {
        Section {
            ForEach($contacts) { $contact in
                ContactEditorRow(
                    contact: $contact,
                    position: position(of: contact.id),
                    canMoveUp: contacts.first?.id != contact.id,
                    canMoveDown: contacts.last?.id != contact.id,
                    move: { offset in move(contact.id, by: offset) },
                    remove: { remove(contact.id) },
                    focus: $focusedID
                )
            }
            .onDelete { contacts.remove(atOffsets: $0) }
            .onMove { contacts.move(fromOffsets: $0, toOffset: $1) }

            Button {
                let draft = ContactDraft()
                withAnimation(.snappy) { contacts.append(draft) }
                focusedID = draft.id
            } label: {
                Label("Agregar contacto", systemImage: "person.crop.circle.badge.plus")
            }
        } header: {
            Text("Contactos")
        } footer: {
            if contacts.count > 1 {
                Text("Mantén presionado un contacto para reordenarlo. El primero es el contacto principal.")
            }
        }
    }

    private func position(of id: ContactDraft.ID) -> Int { (contacts.firstIndex { $0.id == id } ?? 0) + 1 }

    private func move(_ id: ContactDraft.ID, by offset: Int) {
        guard let index = contacts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard contacts.indices.contains(target) else { return }
        withAnimation(.snappy) { contacts.swapAt(index, target) }
    }

    private func remove(_ id: ContactDraft.ID) {
        withAnimation(.snappy) { contacts.removeAll { $0.id == id } }
    }
}

private struct ContactEditorRow: View {
    @Binding var contact: ContactDraft
    var position: Int
    var canMoveUp: Bool
    var canMoveDown: Bool
    var move: (Int) -> Void
    var remove: () -> Void
    var focus: FocusState<ContactDraft.ID?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(name: contact.name.isEmpty ? "\(position)" : contact.name, size: 34)
                TextField("Nombre", text: $contact.name)
                    .font(.body.weight(.semibold))
                    .textContentType(.name)
                    .focused(focus, equals: contact.id)
                Menu {
                    Button("Subir", systemImage: "arrow.up") { move(-1) }.disabled(!canMoveUp)
                    Button("Bajar", systemImage: "arrow.down") { move(1) }.disabled(!canMoveDown)
                    Divider()
                    Button("Quitar contacto", systemImage: "trash", role: .destructive, action: remove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Opciones del contacto \(position)")
            }
            HStack(spacing: 10) {
                fieldIcon("briefcase")
                TextField("Puesto", text: $contact.role)
                    .textContentType(.jobTitle)
            }
            HStack(spacing: 10) {
                fieldIcon("envelope")
                TextField("Correo", text: $contact.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                fieldIcon("phone")
                TextField("Teléfono", text: $contact.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
        }
        .padding(.vertical, 6)
    }

    private func fieldIcon(_ name: String) -> some View {
        Image(systemName: name)
            .foregroundStyle(Theme.brand)
            .frame(width: 22)
            .accessibilityHidden(true)
    }
}

/// Read-only contact card with tap-to-email and tap-to-call.
struct ContactCard: View {
    @ObservedObject var contact: Contact
    var isPrimary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AvatarView(name: contact.name ?? "?", size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name ?? "Sin nombre").font(.headline).lineLimit(1)
                    Text(contact.role ?? "Sin puesto").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if isPrimary {
                    Pill(text: "Principal", symbol: "star.fill", tint: Theme.thread)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if let email = contact.email, let url = ContactLinks.mailto([email]) {
                    ContactLinkRow(symbol: "envelope.fill", text: email, url: url, label: "Enviar correo a \(email)")
                }
                if let phone = contact.phone, let url = ContactLinks.tel(phone) {
                    ContactLinkRow(symbol: "phone.fill", text: phone, url: url, label: "Llamar a \(phone)")
                }
                if contact.email == nil, contact.phone == nil {
                    Text("Sin datos de contacto").font(.footnote).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
        .contextMenu {
            if let email = contact.email {
                Button("Copiar correo", systemImage: "doc.on.doc") { UIPasteboard.general.string = email }
            }
            if let phone = contact.phone {
                Button("Copiar teléfono", systemImage: "doc.on.doc") { UIPasteboard.general.string = phone }
            }
        }
    }
}

private struct ContactLinkRow: View {
    var symbol: String
    var text: String
    var url: URL
    var label: String

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.footnote)
                    .foregroundStyle(Theme.brand)
                    .frame(width: 30, height: 30)
                    .background(Theme.brand.opacity(0.12), in: .circle)
                Text(text).font(.subheadline).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Contacts section for detail screens: header with "email everyone" plus a grid of cards.
struct ContactsSection: View {
    var contacts: [Contact]
    var onAdd: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Contactos", subtitle: subtitle) {
                if let url = ContactLinks.mailto(contacts.compactMap(\.email)), contacts.count > 1 {
                    Link(destination: url) {
                        Label("Enviar correo a todos", systemImage: "envelope.badge.person.crop")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.brand)
                }
            }
            if contacts.isEmpty {
                VStack(spacing: 12) {
                    Text("Aún no hay contactos.").foregroundStyle(.secondary)
                    if let onAdd {
                        Button("Agregar contacto", systemImage: "person.crop.circle.badge.plus", action: onAdd)
                            .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .card()
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 280, spacing: 14), spacing: 14) {
                    ForEach(contacts, id: \.objectID) { contact in
                        ContactCard(contact: contact, isPrimary: contact == contacts.first && contacts.count > 1)
                    }
                }
            }
        }
    }

    private var subtitle: String {
        switch contacts.count {
        case 0: "Sin contactos"
        case 1: "1 contacto"
        default: "\(contacts.count) contactos"
        }
    }
}

/// Compact contact line used on list cards.
struct PrimaryContactLine: View {
    var contacts: [Contact]

    var body: some View {
        if let first = contacts.first {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle").foregroundStyle(Theme.brand)
                Text(first.name ?? first.email ?? "Contacto").lineLimit(1)
                if contacts.count > 1 {
                    Text("+\(contacts.count - 1)").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        } else {
            Label("Sin contactos", systemImage: "person.crop.circle.badge.questionmark")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}
