import SwiftUI

/// Rounded raised card used across the app.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 20
    var radius: CGFloat = Theme.radius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

extension View {
    func card(padding: CGFloat = 20, radius: CGFloat = Theme.radius) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }

    /// Standard screen background: linen canvas with a faint woven texture.
    func ipbScreenBackground() -> some View {
        background {
            ZStack {
                Theme.canvas
                WeaveTexture().opacity(0.5)
            }
            .ignoresSafeArea()
        }
    }
}

/// Section heading with optional trailing accessory.
struct SectionHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.bold))
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

/// Small capsule tag with icon and tint.
struct Pill: View {
    var text: String
    var symbol: String?
    var tint: Color

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            Text(text).lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: .capsule)
    }
}

/// Label/value row used in detail cards.
struct InfoRow: View {
    var label: String
    var value: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.brand)
                    .frame(width: 22)
            }
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

/// Primary call-to-action button style in brand colors.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.brand
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(tint.opacity(isEnabled ? 1 : 0.4), in: .rect(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var ipbPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func ipbPrimary(_ tint: Color) -> PrimaryButtonStyle { PrimaryButtonStyle(tint: tint) }
}
