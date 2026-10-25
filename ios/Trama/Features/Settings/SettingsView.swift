import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Environment(\.managedObjectContext) private var context
    @Environment(\.persistence) private var persistence
    @Environment(SyncEngine.self) private var sync

    @AppStorage("settings.urgencyWindowDays") private var urgencyWindow = 7
    @AppStorage("demo.seeded") private var demoSeeded = false
    @AppStorage(Brand.companyKey) private var companyName = ""

    @State private var showPassword = false
    @State private var confirmSignOut = false

    // Sync
    @State private var showConnect = false
    @State private var confirmDisconnect = false
    @State private var confirmUpload = false

    // Backup
    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingRestore: PendingRestore?

    // Data reset
    @State private var confirmErase = false
    @State private var confirmEraseFinal = false
    @State private var eraseConfirmation = ""

    private var isAdmin: Bool { session.role == .admin }

    var body: some View {
        Form {
            accountSection
            syncSection
            preferencesSection
            dataSection
            if isAdmin {
                Section {
                    LegacyImportPanel()
                } header: {
                    Text("Sistema anterior")
                } footer: {
                    Text(
                        "Copia plantas, clientes, proveedores, estilos, usuarios, proyectos, cortes y reportes del servidor anterior. Puedes repetirlo: los registros se actualizan sin duplicarse. Los usuarios importados quedan inactivos hasta que un administrador les asigne contraseña en Usuarios."
                    )
                }
            }
            aboutSection
            Section {
                Button(role: .destructive) {
                    confirmSignOut = true
                } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .tramaScreenBackground()
        .navigationTitle("Ajustes")
        .sheet(isPresented: $showPassword) { ChangePasswordSheet() }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { Task { await sync.signOut() } }
        } message: {
            if sync.isLinked {
                Text("Para volver a sincronizar, la siguiente persona debe entrar con internet.")
            }
        }
        .sheet(isPresented: $showConnect) { LicenceConnectSheet(prefilledEmail: session.user?.email ?? "") }
        .confirmationDialog("¿Desconectar la licencia?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Desconectar", role: .destructive) {
                Task {
                    await sync.disconnect()
                    toasts.show("Este iPad ya no sincroniza con tu empresa", style: .info)
                }
            }
        } message: {
            Text("Los datos se quedan en este iPad, pero los cambios pendientes de enviar se descartan y ya no se sincronizará.")
        }
        .confirmationDialog("¿Subir todos los datos de este iPad?", isPresented: $confirmUpload, titleVisibility: .visible) {
            Button("Subir datos") { uploadAll() }
        } message: {
            Text("Envía a tu empresa todos los registros de este iPad (por ejemplo, después de importar del sistema anterior). Si un registro cambió en otro dispositivo después, se conserva la versión más reciente.")
        }
        .fileExporter(
            isPresented: $showExporter, document: exportDocument, contentType: .json,
            defaultFilename: BackupService.filename()
        ) { result in
            switch result {
            case .success: toasts.show("Respaldo guardado")
            case .failure(let error): toasts.error(error)
            }
            exportDocument = nil
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): prepareRestore(from: url)
            case .failure(let error): toasts.error(error)
            }
        }
        .confirmationDialog(
            "¿Restaurar respaldo?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            titleVisibility: .visible, presenting: pendingRestore
        ) { pending in
            Button("Reemplazar todos los datos", role: .destructive) { restore(pending) }
        } message: { pending in
            Text(pending.message)
        }
        .confirmationDialog("¿Borrar todos los datos?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Continuar", role: .destructive) {
                eraseConfirmation = ""
                confirmEraseFinal = true
            }
        } message: {
            Text("Se eliminarán plantas, cortes, reportes, catálogos y usuarios de este iPad. Exporta un respaldo antes si lo necesitas.")
        }
        .alert("Confirmación final", isPresented: $confirmEraseFinal) {
            TextField("BORRAR", text: $eraseConfirmation)
                .textInputAutocapitalization(.characters)
            Button("Borrar todo", role: .destructive, action: eraseAll)
                .disabled(eraseConfirmation.trimmingCharacters(in: .whitespaces).uppercased() != "BORRAR")
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Escribe BORRAR para eliminar todos los datos. Esta acción no se puede deshacer.")
        }
    }

    // MARK: Sections

    private var accountSection: some View {
        Section("Cuenta") {
            if let user = session.user {
                HStack(spacing: 16) {
                    AvatarView(name: user.fullName, imageData: user.avatarData, size: 60)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(user.fullName).font(.title3.weight(.bold))
                        Text(user.email ?? "").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Pill(text: user.role.title, symbol: user.role.symbol, tint: Theme.brand)
                            if let plant = user.plant {
                                Pill(text: plant.displayName, symbol: "building.2", tint: Theme.info)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            Button {
                showPassword = true
            } label: {
                Label("Cambiar contraseña", systemImage: "key.fill")
            }
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        Section {
            if sync.isLinked {
                SyncStatusView()
                Button {
                    Task { await sync.sync() }
                } label: {
                    SettingsActionRow(
                        title: sync.isSyncing ? "Sincronizando…" : "Sincronizar", subtitle: "Envía tus cambios y descarga los de tu empresa",
                        symbol: "arrow.triangle.2.circlepath", tint: Theme.brand)
                }
                .disabled(sync.isSyncing || sync.needsReconnect)
                if sync.needsReconnect {
                    Button {
                        showConnect = true
                    } label: {
                        SettingsActionRow(
                            title: "Conectar de nuevo", subtitle: "Tu sesión en la nube terminó; entra con tu contraseña",
                            symbol: "key.icloud", tint: Theme.warning)
                    }
                }
                if isAdmin {
                    Button {
                        confirmUpload = true
                    } label: {
                        SettingsActionRow(
                            title: "Subir todos los datos de este iPad", subtitle: "Útil después de importar del sistema anterior",
                            symbol: "icloud.and.arrow.up", tint: Theme.info)
                    }
                    .disabled(sync.isSyncing || sync.needsReconnect || sync.isReadOnly)
                    Button {
                        confirmDisconnect = true
                    } label: {
                        SettingsActionRow(
                            title: "Desconectar licencia", subtitle: "Deja de sincronizar este iPad", symbol: "icloud.slash", tint: Theme.danger)
                    }
                }
            } else {
                Button {
                    showConnect = true
                } label: {
                    SettingsActionRow(
                        title: "Conectar con mi licencia", subtitle: "Sincroniza este iPad con los demás dispositivos de tu empresa",
                        symbol: "key.icloud.fill", tint: Theme.brand)
                }
            }
        } header: {
            Text("Sincronización")
        } footer: {
            Text(
                sync.isLinked
                    ? "Trama sigue funcionando sin internet. Los cambios se guardan en este iPad y se envían solos al recuperar la conexión."
                    : "Sin licencia, Trama funciona solo en este iPad."
            )
        }
    }

    private var preferencesSection: some View {
        Section {
            if session.role == .admin {
                LabeledContent {
                    TextField("Nombre de la empresa", text: $companyName)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.organizationName)
                } label: {
                    Label("Empresa", systemImage: "building.2")
                }
            }
            Stepper(value: $urgencyWindow, in: 1...30) {
                HStack {
                    Label("Ventana de urgencia", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Text("\(urgencyWindow) \(urgencyWindow == 1 ? "día" : "días")")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: urgencyWindow)
                }
            }
        } header: {
            Text("Preferencias")
        } footer: {
            Text("Un envío es urgente si tiene prendas por enviar y la fecha del cliente cae dentro de esta ventana, o ya venció.")
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        Section {
            if isAdmin {
                Button(action: exportBackup) {
                    SettingsActionRow(
                        title: "Exportar respaldo", subtitle: "Archivo JSON con todos los datos e imágenes", symbol: "square.and.arrow.up",
                        tint: Theme.brand)
                }
                // Restoring or seeding would silently diverge from the company's data, so both
                // are local-only actions.
                if !sync.isLinked {
                    Button {
                        showImporter = true
                    } label: {
                        SettingsActionRow(
                            title: "Restaurar respaldo", subtitle: "Reemplaza los datos de este iPad",
                            symbol: "arrow.counterclockwise.circle", tint: Theme.warning)
                    }
                    Button(action: loadDemo) {
                        SettingsActionRow(
                            title: "Cargar datos de ejemplo",
                            subtitle: demoSeeded ? "Ya cargados en este iPad" : "Solo si no hay datos operativos",
                            symbol: "sparkles", tint: Theme.thread)
                    }
                }
                Button {
                    confirmErase = true
                } label: {
                    SettingsActionRow(
                        title: "Borrar todos los datos", subtitle: "Regresa Trama a su configuración inicial", symbol: "trash",
                        tint: Theme.danger)
                }
            } else {
                Label("Solo el administrador puede respaldar, restaurar o borrar los datos.", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Datos")
        } footer: {
            if isAdmin {
                Text(
                    sync.isLinked
                        ? "Los respaldos incluyen las contraseñas cifradas de los usuarios. Para restaurar un respaldo o cargar datos de ejemplo, primero desconecta la licencia. Borrar los datos también desconecta este iPad."
                        : "Los respaldos incluyen las contraseñas cifradas de los usuarios. Guárdalos en un lugar seguro."
                )
            }
        }
    }

    private var aboutSection: some View {
        Section("Acerca de") {
            LabeledContent("Versión", value: BackupService.appVersion)
            LabeledContent {
                Text(connectivity.isOnline ? "En línea" : "Sin conexión")
                    .foregroundStyle(connectivity.isOnline ? Theme.success : Theme.warning)
            } label: {
                Label("Conexión", systemImage: connectivity.isOnline ? "wifi" : "wifi.slash")
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Funciona sin conexión", systemImage: "icloud.slash")
                    .font(.subheadline.weight(.semibold))
                Text(
                    "Todos los datos viven en este iPad (Core Data). Puedes registrar cortes, asignaciones y reportes sin internet; con licencia, la conexión sincroniza los cambios con tu empresa."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            LabeledContent {
                Text(storeLocation).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2).truncationMode(.head)
                    .textSelection(.enabled)
            } label: {
                Label("Almacenamiento", systemImage: "internaldrive")
            }
        }
    }

    private var storeLocation: String {
        guard let url = persistence.container.persistentStoreDescriptions.first?.url, url.path != "/dev/null" else {
            return "En memoria (demostración)"
        }
        return url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    // MARK: Actions

    private func exportBackup() {
        do {
            exportDocument = BackupDocument(data: try BackupService.export(context: context))
            showExporter = true
        } catch {
            toasts.error(error)
        }
    }

    private func prepareRestore(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let summary = try BackupService.inspect(data)
            pendingRestore = PendingRestore(data: data, summary: summary)
        } catch {
            toasts.error(error)
        }
    }

    private func restore(_ pending: PendingRestore) {
        do {
            try BackupService.restore(pending.data, into: persistence)
            session.restore()
            if session.isSignedIn {
                toasts.show("Respaldo restaurado: \(Fmt.int(pending.summary.total)) registros")
            } else {
                // The current user is not in the backup (or is inactive there): back to the login screen.
                toasts.show("Respaldo restaurado. Inicia sesión con una cuenta del respaldo.", style: .info)
            }
        } catch {
            toasts.error(error)
        }
        pendingRestore = nil
    }

    private func loadDemo() {
        let operational = context.count(Plant.self) + context.count(CutOrder.self) + context.count(Client.self) + context.count(Style.self)
        guard operational == 0 else {
            toasts.show("Ya hay datos en este iPad. Bórralos primero para cargar los datos de ejemplo.", style: .info)
            return
        }
        DemoSeeder.seed(into: context)
        demoSeeded = true
        toasts.show("Datos de ejemplo cargados. Cuentas demo con contraseña \(DemoSeeder.demoPassword).")
    }

    private func uploadAll() {
        Task {
            do {
                try await sync.uploadAllLocalData()
                if let error = sync.lastError {
                    toasts.show(error, style: .error)
                } else {
                    toasts.show("Datos de este iPad enviados a tu empresa")
                }
            } catch {
                toasts.error(error)
            }
        }
    }

    private func eraseAll() {
        do {
            if sync.isLinked { Task { await sync.disconnect() } }
            try persistence.eraseAll()
            demoSeeded = false
            session.signOut()
            toasts.show("Se borraron todos los datos", style: .info)
        } catch {
            toasts.error(error)
        }
    }
}

// MARK: - Support types

private struct PendingRestore: Identifiable {
    let id = UUID()
    var data: Data
    var summary: BackupService.Summary

    var message: String {
        let date = summary.exportedAt.map { Fmt.date($0) } ?? "fecha desconocida"
        let counts = summary.counts.filter { $0.1 > 0 }.map { "\($0.1) \($0.0.lowercased())" }.joined(separator: ", ")
        return
            "Respaldo del \(date) (Trama \(summary.appVersion ?? "?")): \(counts.isEmpty ? "sin registros" : counts). Se borrarán todos los datos actuales de este iPad."
    }
}

/// Wraps backup bytes for `fileExporter`.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsActionRow: View {
    var title: String
    var subtitle: String
    var symbol: String
    var tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Password

private struct ChangePasswordSheet: View {
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var error: String?

    private var canSave: Bool { !current.isEmpty && !new.isEmpty && !confirm.isEmpty }

    var body: some View {
        FormSheet(title: "Cambiar contraseña", canSave: canSave, onSave: save) {
            Section {
                SecureField("Contraseña actual", text: $current).textContentType(.password)
            }
            Section {
                SecureField("Nueva contraseña (mín. 6 caracteres)", text: $new).textContentType(.newPassword)
                SecureField("Confirmar nueva contraseña", text: $confirm).textContentType(.newPassword)
            } footer: {
                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(Theme.danger)
                }
            }
        }
        .presentationDetents([.medium])
        .animation(.spring(duration: 0.3), value: error)
    }

    private func save() {
        guard let user = session.user else { return }
        guard PasswordHasher.verify(current, hash: user.passwordHash, salt: user.passwordSalt) else {
            return fail("La contraseña actual no es correcta.")
        }
        guard new.count >= 6 else { return fail(AuthError.weakPassword.localizedDescription) }
        guard new == confirm else { return fail("Las contraseñas nuevas no coinciden.") }
        guard new != current else { return fail("La nueva contraseña debe ser distinta a la actual.") }
        Session.setPassword(new, for: user)
        user.touch()
        do {
            try context.saveTracked()
            toasts.show("Contraseña actualizada")
            dismiss()
        } catch {
            context.rollback()
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        error = message
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

#Preview("Ajustes") {
    let persistence = PersistenceController.preview
    let session = Session(context: persistence.viewContext)
    if let admin = Session.findUser(email: "admin@demo.local", in: persistence.viewContext) { session.adopt(admin) }
    return NavigationStack { SettingsView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(\.persistence, persistence)
        .environment(session)
        .environment(ToastCenter())
        .environment(AppRouter())
        .environment(ConnectivityMonitor())
        .environment(
            SyncEngine(
                persistence: persistence, session: session, toasts: nil, secrets: MemorySecretStore(),
                defaults: UserDefaults(suiteName: "trama.preview") ?? .standard, enabled: false))
}
