import SwiftUI

/// First launch: create the first administrator, or explore with demo data.
struct OnboardingView: View {
    var onFinished: () -> Void

    @Environment(\.managedObjectContext) private var context
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @AppStorage("demo.seeded") private var demoSeeded = false

    @AppStorage(Brand.companyKey) private var companyName = ""
    @State private var company = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var showConnect = false

    var body: some View {
        AuthLayout {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configura Trama")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Registra tu empresa y la cuenta de administrador de este iPad. Podrás agregar a tus gerentes después.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    AuthField(symbol: "building.2.fill", placeholder: "Nombre de tu empresa", text: $company)
                        .textContentType(.organizationName)
                    HStack(spacing: 14) {
                        AuthField(symbol: "person.fill", placeholder: "Nombre", text: $firstName)
                            .textContentType(.givenName)
                        AuthField(symbol: "person", placeholder: "Apellido", text: $lastName)
                            .textContentType(.familyName)
                    }
                    AuthField(symbol: "envelope.fill", placeholder: "Correo electrónico", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    AuthField(symbol: "lock.fill", placeholder: "Contraseña (mín. 6 caracteres)", text: $password, secure: true)
                        .textContentType(.newPassword)
                }

                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.danger)
                }

                Button(action: createAdmin) {
                    Label("Crear administrador", systemImage: "crown.fill")
                }
                .buttonStyle(.tramaPrimary)

                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(Theme.stroke)
                    Text("o").font(.caption).foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(Theme.stroke)
                }

                LicenceConnectButton(linkedCompany: nil) { showConnect = true }

                Button(action: loadDemo) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Explorar con datos de ejemplo", systemImage: "sparkles")
                            .font(.headline)
                        Text("Plantas, clientes, cortes y reportes ficticios. Puedes borrarlos en Ajustes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Theme.thread.opacity(0.14), in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.thread.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showConnect) {
            LicenceConnectSheet(prefilledEmail: email) { onFinished() }
        }
    }

    private func createAdmin() {
        do {
            let user = try Session.createUser(
                firstName: firstName, lastName: lastName, email: email, phone: "", password: password,
                role: .admin, plant: nil, avatar: nil, in: context
            )
            companyName = company.trimmingCharacters(in: .whitespaces)
            session.adopt(user)
            toasts.show("¡Listo, \(user.firstName ?? "")! Trama está configurado.")
            onFinished()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadDemo() {
        DemoSeeder.seed(into: context)
        demoSeeded = true
        companyName = "Textiles Demo"
        if let admin = Session.findUser(email: "admin@demo.local", in: context) {
            session.adopt(admin)
            toasts.show("Datos de ejemplo cargados. Sesión iniciada como administrador.")
        }
        onFinished()
    }
}
