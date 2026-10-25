import SwiftUI

struct LoginView: View {
    @Environment(Session.self) private var session
    @Environment(SyncEngine.self) private var sync
    @AppStorage("demo.seeded") private var demoSeeded = false

    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var shake = 0
    @State private var signingIn = false
    @State private var showConnect = false
    @FocusState private var focus: Field?

    enum Field { case email, password }

    var body: some View {
        AuthLayout {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bienvenido de nuevo")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Ingresa con tu correo de trabajo para continuar.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    AuthField(symbol: "envelope.fill", placeholder: "Correo electrónico", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                    AuthField(symbol: "lock.fill", placeholder: "Contraseña", text: $password, secure: true)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                }
                .modifier(Shake(animatableData: CGFloat(shake)))

                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.danger)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Button(action: signIn) {
                    if signingIn {
                        ProgressView().tint(.white)
                    } else {
                        Label("Entrar", systemImage: "arrow.right")
                            .labelStyle(TrailingIconLabelStyle())
                    }
                }
                .buttonStyle(.tramaPrimary)
                .keyboardShortcut(.defaultAction)
                .disabled(signingIn)

                LicenceConnectButton(linkedCompany: sync.account?.tenantName) { showConnect = true }

                if demoSeeded {
                    DemoAccountsHint { account in
                        email = account
                        password = DemoSeeder.demoPassword
                        signIn()
                    }
                }
            }
        }
        .animation(.spring(duration: 0.35), value: error)
        .sheet(isPresented: $showConnect) { LicenceConnectSheet(prefilledEmail: email) }
    }

    private func signIn() {
        guard !signingIn else { return }
        signingIn = true
        Task {
            defer { signingIn = false }
            do {
                // Local first (offline); falls back to the platform when this iPad has a licence.
                try await sync.signIn(email: email, password: password)
            } catch {
                self.error = error.localizedDescription
                withAnimation(.default) { shake += 1 }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

/// Secondary entry to licence activation, shared by login and onboarding.
struct LicenceConnectButton: View {
    var linkedCompany: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: linkedCompany == nil ? "key.icloud.fill" : "checkmark.icloud.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.brand)
                VStack(alignment: .leading, spacing: 3) {
                    Text(linkedCompany == nil ? "Conectar con mi licencia" : "Conectado a \(linkedCompany!)")
                        .font(.headline)
                    Text(
                        linkedCompany == nil
                            ? "Entra con tu cuenta de Trama para sincronizar los datos de tu empresa."
                            : "Entra con tu correo y contraseña de siempre, aunque no haya internet."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Theme.brand.opacity(0.08), in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.brand.opacity(0.25)))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

/// Quick-pick demo accounts, shown only when the demo dataset was loaded.
private struct DemoAccountsHint: View {
    var pick: (String) -> Void
    private let accounts: [(String, Role)] = [
        ("admin@demo.local", .admin), ("cortes@demo.local", .cutManager), ("planta@demo.local", .plantManager),
        ("envios@demo.local", .shippingManager),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cuentas de demostración").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowRow(spacing: 8) {
                ForEach(accounts, id: \.0) { email, role in
                    Button {
                        pick(email)
                    } label: {
                        Label(role.title, systemImage: role.symbol)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.brand.opacity(0.1), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.brand)
                }
            }
        }
    }
}

/// Split brand/form layout shared by login and onboarding.
struct AuthLayout<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 900
            HStack(spacing: 0) {
                if wide {
                    BrandPanel()
                        .frame(width: geo.size.width * 0.48)
                }
                ScrollView {
                    VStack {
                        if !wide {
                            BrandPanel(compact: true)
                                .frame(height: 260)
                                .clipShape(.rect(cornerRadius: 28, style: .continuous))
                                .padding(.bottom, 12)
                        }
                        content
                            .frame(maxWidth: 440)
                            .padding(.vertical, 40)
                    }
                    .padding(.horizontal, 40)
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: .infinity)
                .background(Theme.canvas)
            }
        }
        .ignoresSafeArea(.container, edges: .vertical)
    }
}

private struct BrandPanel: View {
    var compact = false
    @AppStorage(Brand.companyKey) private var companyName = ""
    @Environment(ConnectivityMonitor.self) private var connectivity

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LoomBackdrop()
            VStack(alignment: .leading, spacing: compact ? 10 : 18) {
                Image("AppMark")
                    .resizable()
                    .frame(width: compact ? 64 : 96, height: compact ? 64 : 96)
                    .clipShape(.rect(cornerRadius: compact ? 16 : 24, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
                Text(Brand.productName)
                    .font(.system(size: compact ? 28 : 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(companyName.isEmpty ? Brand.tagline : "\(Brand.tagline) · \(companyName)")
                    .font(compact ? .headline : .title2.weight(.semibold))
                    .foregroundStyle(Theme.thread)
                Text("Cortes, plantas y envíos en un solo tablero.\nFunciona sin conexión: tus datos viven en este iPad.")
                    .font(compact ? .callout : .title3)
                    .foregroundStyle(.white.opacity(0.8))
                Label(
                    connectivity.isOnline ? "En línea" : "Sin conexión · modo local",
                    systemImage: connectivity.isOnline ? "wifi" : "wifi.slash"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.14), in: .capsule)
                .foregroundStyle(.white)
            }
            .padding(compact ? 28 : 56)
        }
    }
}

struct AuthField: View {
    var symbol: String
    var placeholder: LocalizedStringKey
    @Binding var text: String
    var secure = false
    @State private var reveal = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.brand).frame(width: 22)
            Group {
                if secure && !reveal {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body)
            if secure {
                Button {
                    reveal.toggle()
                } label: {
                    Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reveal ? "Ocultar contraseña" : "Mostrar contraseña")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title; configuration.icon
        }
    }
}

/// Horizontal shake for invalid input.
struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Simple wrapping row layout.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            width = max(width, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
