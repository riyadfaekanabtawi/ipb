import SwiftUI

/// Big-number KPI tile with animated numeric transitions.
struct KPITile: View {
    var title: LocalizedStringKey
    var value: String
    var symbol: String
    var tint: Color = Theme.brand
    var footnote: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { tile }
                .buttonStyle(.plain)
        } else {
            tile
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))
                Spacer()
                if action != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                if let footnote {
                    Text(footnote).font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
        .accessibilityElement(children: .combine)
    }
}

/// Horizontal capacity bar with threshold coloring and an optional "preview" overlay
/// showing what an assignment would add.
struct CapacityBar: View {
    var used: Double
    var max: Double
    var preview: Double = 0
    var height: CGFloat = 12

    private var ratio: Double { max > 0 ? used / max : 0 }
    private var previewRatio: Double { max > 0 ? (used + preview) / max : 0 }

    static func tint(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.7: Theme.success
        case ..<0.95: Theme.warning
        default: Theme.danger
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                if preview > 0 {
                    Capsule()
                        .fill(Self.tint(for: previewRatio).opacity(0.35))
                        .frame(width: geo.size.width * min(1, previewRatio))
                }
                Capsule()
                    .fill(Self.tint(for: ratio).gradient)
                    .frame(width: geo.size.width * min(1, ratio))
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.45), value: used)
        .animation(.spring(duration: 0.45), value: preview)
        .accessibilityElement()
        .accessibilityLabel("Capacidad usada \(Fmt.percent(ratio))")
    }
}

/// Circular progress ring.
struct ProgressRing: View {
    var progress: Double
    var tint: Color = Theme.brand
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(duration: 0.6), value: progress)
    }
}

/// Initials or image avatar with a stable accent color.
struct AvatarView: View {
    var name: String
    var imageData: Data?
    var size: CGFloat = 40
    var symbol: String?

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Theme.accent(for: name).gradient)
                    if let symbol {
                        Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold))
                    } else {
                        Text(initials).font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.3, style: .continuous))
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

/// Image thumbnail for styles/projects with a woven placeholder.
struct SwatchImage: View {
    var data: Data?
    var name: String
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Theme.accent(for: name).gradient)
                    WeaveTexture(spacing: 10, ink: .white.opacity(0.18))
                    Image(systemName: "tshirt")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(.rect)
    }
}
