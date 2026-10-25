import SwiftUI

/// User administration (admins only).
struct UsersView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [
        NSSortDescriptor(keyPath: \AppUser.firstName, ascending: true),
        NSSortDescriptor(keyPath: \AppUser.lastName, ascending: true),
    ])
    private var users: FetchedResults<AppUser>

    enum Filter: String, CaseIterable, Identifiable {
        case active = "Activos"
        case inactive = "Inactivos"
        case all = "Todos"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .active
    @State private var roleFilter: Role?
    @State private var search = ""
    @State private var editor: UserEditorTarget?
    @State private var resettingPassword: AppUser?
    @State private var pendingDelete: AppUser?

    private var visible: [AppUser] {
        users.filter { user in
            let stateMatches =
                switch filter {
                case .active: user.isActive
                case .inactive: !user.isActive
                case .all: true
                }
            return stateMatches && (roleFilter == nil || user.role == roleFilter)
                && CatalogSearch.matches(search, [user.fullName, user.email, user.phone, user.role.title, user.plant?.name])
        }
    }

    var body: some View {
        if session.role != .admin {
            ContentUnavailableView(
                "Solo administradores", systemImage: "lock.fill",
                description: Text("Pide a un administrador que gestione los usuarios.")
            )
            .navigationTitle("Usuarios")
        } else {
            content
        }
    }

    private var content: some View {
        let visible = visible
        return VStack(alignment: .leading, spacing: 24) {
            LazyVGrid(columns: AdaptiveGrid.adaptive(min: 150), spacing: 18) {
                ForEach(Role.allCases) { role in
                    KPITile(
                        title: role.title,
                        value: Fmt.int(users.filter { $0.role == role && $0.isActive }.count),
                        symbol: role.symbol,
                        tint: Theme.accent(for: role.rawValue),
                        footnote: roleFilter == role ? "Filtrando · toca para quitar" : nil
                    ) {
                        withAnimation(.snappy) { roleFilter = roleFilter == role ? nil : role }
                    }
                }
            }

            Picker("Mostrar", selection: $filter.animation(.snappy)) {
                ForEach(Filter.allCases) { option in
                    Text("\(option.rawValue) (\(count(option)))").tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 480)

            if visible.isEmpty {
                if search.isEmpty {
                    ContentUnavailableView(
                        "Sin usuarios \(filter.rawValue.lowercased())", systemImage: "person.crop.circle.badge.questionmark")
                } else {
                    ContentUnavailableView.search(text: search)
                }
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 320), spacing: 18) {
                    ForEach(visible, id: \.objectID) { user in
                        UserCard(user: user, isCurrent: user == session.user) { active in
                            setActive(active, for: user)
                        }
                        .onTapGesture { editor = .edit(user) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: "Editar") { editor = .edit(user) }
                        .contextMenu { menu(for: user) }
                    }
                }
                .animation(.spring(duration: 0.4), value: visible.map(\.objectID))
            }
        }
        .catalogScroll()
        .navigationTitle("Usuarios")
        .searchable(text: $search, prompt: "Buscar por nombre, correo o puesto")
        .toolbar { AddToolbarButton(title: "Nuevo usuario") { editor = .new } }
        .sheet(item: $editor) { target in UserEditorSheet(user: target.user) }
        .sheet(item: $resettingPassword) { user in PasswordResetSheet(user: user) }
        .confirmDelete(
            "¿Eliminar a \(pendingDelete?.fullName ?? "este usuario")?", item: $pendingDelete,
            message: "Perderá el acceso a IPB. Si solo quieres pausar su acceso, desactívalo."
        ) { user in
            let name = user.fullName
            do {
                try CatalogService(context: context).deleteUser(user, actingUser: session.user)
                toasts.show("Usuario «\(name)» eliminado")
            } catch {
                toasts.error(error)
            }
        }
    }

    @ViewBuilder
    private func menu(for user: AppUser) -> some View {
        let isCurrent = user == session.user
        Button("Editar", systemImage: "pencil") { editor = .edit(user) }
        Button("Restablecer contraseña", systemImage: "key.fill") { resettingPassword = user }
        if user.isActive {
            Button("Desactivar", systemImage: "person.crop.circle.badge.xmark") { setActive(false, for: user) }
                .disabled(isCurrent)
        } else {
            Button("Activar", systemImage: "person.crop.circle.badge.checkmark") { setActive(true, for: user) }
        }
        Divider()
        Button("Eliminar", systemImage: "trash", role: .destructive) { pendingDelete = user }
            .disabled(isCurrent)
    }

    private func count(_ option: Filter) -> Int {
        switch option {
        case .active: users.filter(\.isActive).count
        case .inactive: users.filter { !$0.isActive }.count
        case .all: users.count
        }
    }

    private func setActive(_ active: Bool, for user: AppUser) {
        do {
            try withAnimation(.snappy) {
                try CatalogService(context: context).setActive(active, for: user, actingUser: session.user)
            }
            toasts.show(active ? "\(user.fullName) puede volver a ingresar" : "\(user.fullName) fue desactivado")
        } catch {
            toasts.error(error)
        }
    }
}

enum UserEditorTarget: Identifiable {
    case new
    case edit(AppUser)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let user): user.objectID.uriRepresentation().absoluteString
        }
    }

    var user: AppUser? {
        if case .edit(let user) = self { return user }
        return nil
    }
}

private struct UserCard: View {
    @ObservedObject var user: AppUser
    var isCurrent: Bool
    var setActive: (Bool) -> Void

    var body: some View {
        let role = user.role
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AvatarView(name: user.fullName, imageData: user.avatarData, size: 58)
                    .saturation(user.isActive ? 1 : 0)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(user.fullName).font(.headline).lineLimit(1)
                        if isCurrent { Pill(text: "Tú", symbol: nil, tint: Theme.brand) }
                    }
                    Pill(text: role.title, symbol: role.symbol, tint: Theme.brand)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                if role == .plantManager {
                    Label(user.plant?.displayName ?? "Sin planta asignada", systemImage: "building.2")
                        .foregroundStyle(user.plant == nil ? Theme.danger : .primary)
                }
                Label(user.email ?? "Sin correo", systemImage: "envelope")
                if let phone = user.phone, !phone.isEmpty {
                    Label(phone, systemImage: "phone")
                }
            }
            .font(.subheadline)
            .lineLimit(1)
            .foregroundStyle(.secondary)

            Divider()

            HStack {
                if user.isActive {
                    Label("Con acceso", systemImage: "checkmark.shield.fill").foregroundStyle(Theme.success)
                } else {
                    Label("Sin acceso a la app", systemImage: "lock.fill").foregroundStyle(Theme.warning)
                }
                Spacer()
                Toggle("Activo", isOn: Binding(get: { user.isActive }, set: setActive))
                    .labelsHidden()
                    .disabled(isCurrent)
                    .accessibilityLabel(user.isActive ? "Usuario activo" : "Usuario inactivo")
            }
            .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .opacity(user.isActive ? 1 : 0.75)
        .contentShape(.rect)
    }
}

struct UserEditorSheet: View {
    var user: AppUser?

    @Environment(\.managedObjectContext) private var context
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Plant.name, ascending: true)])
    private var plants: FetchedResults<Plant>

    @State private var draft = UserDraft()
    @State private var password = ""
    @State private var confirmation = ""
    @State private var loaded = false

    private var isNew: Bool { user == nil }
    private var isSelf: Bool { user != nil && user == session.user }

    private var passwordProblem: String? {
        guard isNew else { return nil }
        if password.isEmpty { return nil }
        if password.count < 6 { return "Al menos 6 caracteres." }
        if !confirmation.isEmpty, confirmation != password { return "Las contraseñas no coinciden." }
        return nil
    }

    private var canSave: Bool {
        let basics =
            !draft.firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.email.trimmingCharacters(in: .whitespaces).isEmpty
            && (draft.role != .plantManager || draft.plant != nil)
        guard isNew else { return basics }
        return basics && password.count >= 6 && password == confirmation
    }

    var body: some View {
        FormSheet(title: isNew ? "Nuevo usuario" : "Editar usuario", saveTitle: isNew ? "Crear" : "Guardar", canSave: canSave, onSave: save)
        {
            Section {
                HStack(spacing: 18) {
                    AvatarView(
                        name: "\(draft.firstName) \(draft.lastName)".trimmingCharacters(in: .whitespaces).isEmpty
                            ? "?" : "\(draft.firstName) \(draft.lastName)",
                        imageData: draft.avatar, size: 72)
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Nombre", text: $draft.firstName).textContentType(.givenName).font(.headline)
                        TextField("Apellido", text: $draft.lastName).textContentType(.familyName)
                    }
                }
                .padding(.vertical, 4)
                PhotoField(title: "Foto de perfil", data: $draft.avatar)
            } header: {
                Text("Perfil")
            }

            Section("Contacto") {
                TextField("Correo electrónico", text: $draft.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Teléfono", text: $draft.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }

            Section {
                Picker("Puesto", selection: $draft.role.animation(.snappy)) {
                    ForEach(Role.allCases) { role in
                        Label(role.title, systemImage: role.symbol).tag(role)
                    }
                }
                .disabled(isSelf)
                if draft.role == .plantManager {
                    Picker("Planta", selection: $draft.plant) {
                        Text("Elegir planta").tag(Plant?.none)
                        ForEach(plants, id: \.objectID) { plant in
                            Text(plant.displayName).tag(Optional(plant))
                        }
                    }
                }
            } header: {
                Text("Puesto")
            } footer: {
                if isSelf {
                    Text("No puedes cambiar tu propio puesto.")
                } else if draft.role == .plantManager {
                    Text(
                        draft.plant == nil
                            ? "Un gerente de planta debe tener una planta asignada." : "Solo verá la producción de su planta.")
                }
            }

            if isNew {
                Section {
                    SecureField("Contraseña", text: $password).textContentType(.newPassword)
                    SecureField("Confirmar contraseña", text: $confirmation).textContentType(.newPassword)
                } header: {
                    Text("Contraseña")
                } footer: {
                    if let passwordProblem {
                        Text(passwordProblem).foregroundStyle(Theme.danger)
                    } else {
                        Text("Mínimo 6 caracteres. El usuario podrá ingresar sin conexión con ella.")
                    }
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let user { draft = UserDraft(user) }
        }
    }

    private func save() {
        let service = CatalogService(context: context)
        do {
            if let user {
                try service.updateUser(user, with: draft, actingUser: session.user)
                // Refresh the sidebar footer when editing yourself.
                if isSelf { session.restore() }
                toasts.show("Usuario actualizado")
            } else {
                let created = try service.createUser(draft, password: password)
                toasts.show("Usuario «\(created.fullName)» creado")
            }
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

struct PasswordResetSheet: View {
    @ObservedObject var user: AppUser

    @Environment(\.managedObjectContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        FormSheet(
            title: "Restablecer contraseña", saveTitle: "Restablecer",
            canSave: password.count >= 6 && password == confirmation, onSave: save
        ) {
            Section {
                HStack(spacing: 14) {
                    AvatarView(name: user.fullName, imageData: user.avatarData, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.fullName).font(.headline)
                        Text(user.email ?? "").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                SecureField("Nueva contraseña", text: $password).textContentType(.newPassword)
                SecureField("Confirmar contraseña", text: $confirmation).textContentType(.newPassword)
            } footer: {
                if !password.isEmpty, password.count < 6 {
                    Text("Al menos 6 caracteres.").foregroundStyle(Theme.danger)
                } else if !confirmation.isEmpty, confirmation != password {
                    Text("Las contraseñas no coinciden.").foregroundStyle(Theme.danger)
                } else {
                    Text("Comparte la nueva contraseña con el usuario en persona.")
                }
            }
        }
    }

    private func save() {
        do {
            try CatalogService(context: context).resetPassword(password, for: user)
            toasts.show("Contraseña de \(user.fullName) restablecida")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

#Preview("Usuarios") {
    NavigationStack { UsersView() }
        .catalogPreviewEnvironment()
}
