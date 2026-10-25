import SwiftUI

/// Switches between onboarding (first launch), sign in, and the main shell.
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @State private var onboardingRefresh = 0

    var body: some View {
        ZStack {
            if session.isSignedIn {
                MainShell()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else if session.needsOnboarding {
                OnboardingView { onboardingRefresh += 1 }
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .id(onboardingRefresh)
        .animation(.smooth(duration: 0.45), value: session.isSignedIn)
        .overlay(alignment: .bottom) { ToastOverlay() }
    }
}

struct ToastOverlay: View {
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        if let toast = toasts.current {
            HStack(spacing: 12) {
                Image(systemName: icon(toast.style))
                    .font(.title3)
                    .foregroundStyle(tint(toast.style))
                    .symbolEffect(.bounce, value: toast.id)
                Text(toast.message)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(tint(toast.style).opacity(0.35)))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
            .padding(.bottom, 28)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture { toasts.dismiss() }
            .id(toast.id)
            .accessibilityAddTraits(.isStaticText)
        }
    }

    private func icon(_ style: ToastCenter.Toast.Style) -> String {
        switch style {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.octagon.fill"
        case .info: "info.circle.fill"
        }
    }

    private func tint(_ style: ToastCenter.Toast.Style) -> Color {
        switch style {
        case .success: Theme.success
        case .error: Theme.danger
        case .info: Theme.info
        }
    }
}
