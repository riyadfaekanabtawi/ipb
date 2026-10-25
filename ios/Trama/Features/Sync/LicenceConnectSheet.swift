import CoreData
import SwiftUI

/// "Conectar con mi licencia": email + password against the Trama platform. Links this iPad to
/// the company, downloads its data and keeps working offline afterwards.
struct LicenceConnectSheet: View {
    var prefilledEmail = ""
    var onConnected: () -> Void = {}

    @Environment(SyncEngine.self) private var sync
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var localData: SyncEngine.LocalData = .keepAndUpload
    @State private var error: String?
    @State private var working = false

    /// Data already on this iPad that isn't linked to a company yet.
    private var hasLocalData: Bool {
        !sync.isLinked && (context.count(AppUser.self) + context.count(Plant.self) + context.count(CutOrder.self)) > 0
    }

    private var canSave: Bool { !working && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty }

    var body: some View {
        FormSheet(title: "Conectar con mi licencia", saveTitle: "Conectar", canSave: canSave, onSave: connect) {
            Section {
                TextField("Correo electrónico", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Contraseña", text: $password)
                    .textContentType(.password)
                    .onSubmit { if canSave { connect() } }
            } header: {
                Text("Cuenta de Trama")
            } footer: {
                Text(
                    "Usa el correo y la contraseña que activaste desde la invitación de tu empresa. Después podrás entrar aunque no haya internet."
                )
            }

            if hasLocalData {
                Section {
                    Picker("Datos de este iPad", selection: $localData) {
                        Text("Conservar y subir a la empresa").tag(SyncEngine.LocalData.keepAndUpload)
                        Text("Reemplazar con los de la empresa").tag(SyncEngine.LocalData.replace)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Este iPad ya tiene datos")
                } footer: {
                    Text(
                        localData == .replace
                            ? "Se borrarán los datos locales de este iPad y se descargarán los de tu empresa. Exporta un respaldo antes si lo necesitas."
                            : "Los datos de este iPad se combinan con los de tu empresa. Si eres administrador, también se suben a la nube."
                    )
                }
            }

            if working || error != nil {
                Section {
                    if working {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Conectando y descargando los datos de tu empresa…").foregroundStyle(.secondary)
                        }
                    } else if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(Theme.danger)
                    }
                }
            }
        }
        .interactiveDismissDisabled(working)
        .onAppear { if email.isEmpty { email = prefilledEmail } }
        .animation(.spring(duration: 0.3), value: error)
    }

    private func connect() {
        working = true
        error = nil
        Task {
            defer { working = false }
            do {
                try await sync.connect(email: email, password: password, localData: hasLocalData ? localData : .keepAndUpload)
                if let tenant = sync.account?.tenantName {
                    toasts.show("Conectado a \(tenant)")
                } else {
                    toasts.show("Conectado a tu empresa")
                }
                onConnected()
                dismiss()
            } catch {
                self.error = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

/// Status card for Ajustes → Sincronización.
struct SyncStatusView: View {
    @Environment(SyncEngine.self) private var sync
    @Environment(ConnectivityMonitor.self) private var connectivity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))
                    .symbolEffect(.pulse, isActive: sync.isSyncing)
                VStack(alignment: .leading, spacing: 3) {
                    Text(sync.account?.tenantName ?? String(localized: "Sin licencia")).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let licence = sync.licence {
                    Pill(
                        text: "\(licence.planTitle) · \(licence.statusTitle)", symbol: "checkmark.seal",
                        tint: licence.writable ? Theme.success : Theme.warning)
                }
            }
            if let error = sync.lastError, !sync.isSyncing {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if sync.isSyncing { return String(localized: "Sincronizando…") }
        var parts: [String] = []
        if let email = sync.account?.email { parts.append(email) }
        if let last = sync.lastSyncAt {
            parts.append(String(localized: "Última sincronización \(last.formatted(.relative(presentation: .named)))"))
        } else {
            parts.append(String(localized: "Aún no se sincroniza"))
        }
        if sync.pendingCount > 0 { parts.append(String(localized: "\(sync.pendingCount) cambios pendientes")) }
        if !connectivity.isOnline { parts.append(String(localized: "sin conexión")) }
        return parts.joined(separator: " · ")
    }

    private var symbol: String {
        if sync.needsReconnect { return "person.crop.circle.badge.exclamationmark" }
        if sync.lastError != nil { return "exclamationmark.icloud" }
        return sync.pendingCount > 0 ? "icloud.and.arrow.up" : "checkmark.icloud"
    }

    private var tint: Color {
        if sync.needsReconnect || sync.lastError != nil || sync.isReadOnly { return Theme.warning }
        return Theme.brand
    }
}

/// Banner above every section when the licence is read-only or the cloud session ended.
struct SyncBanner: View {
    @Environment(SyncEngine.self) private var sync
    @Environment(AppRouter.self) private var router
    @Environment(Session.self) private var session

    var body: some View {
        if let message {
            HStack(spacing: 12) {
                Image(systemName: sync.isReadOnly ? "lock.fill" : "icloud.slash")
                    .foregroundStyle(Theme.warning)
                Text(message)
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if session.role.sections.contains(.settings) {
                    Button("Ajustes") { router.open(.settings) }
                        .font(.callout.weight(.semibold))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Theme.warning.opacity(0.14))
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.warning.opacity(0.35)).frame(height: 1) }
            .accessibilityElement(children: .combine)
        }
    }

    private var message: String? {
        if sync.isReadOnly {
            if let status = sync.licence?.statusTitle {
                return String(localized: "Solo lectura (licencia: \(status)). Puedes consultar los datos, pero no registrar cambios.")
            }
            return String(localized: "Solo lectura: tu licencia no está activa. Puedes consultar los datos, pero no registrar cambios.")
        }
        if sync.needsReconnect {
            return String(localized: "La sincronización está en pausa. Conecta tu licencia de nuevo en Ajustes para enviar tus cambios.")
        }
        return nil
    }
}
