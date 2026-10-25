import SwiftUI
import UIKit

/// Trama design tokens. Palette comes from weaving: a deep petrol-teal warp and a
/// thread-spool yellow weft, on warm "linen" neutrals.
/// Name of the customer company shown in the app (set during onboarding or in Ajustes).
enum Brand {
    static let productName = "Trama"
    static let tagline = "Control de producción textil"
    static let companyKey = "company.name"
}

enum Theme {
    // MARK: Brand
    static let brand = Color(light: 0x145C6E, dark: 0x3FA7BD)
    static let brandDeep = Color(light: 0x0B3440, dark: 0x0B2A33)
    static let thread = Color(light: 0xE8B314, dark: 0xF4C430)

    // MARK: Semantic
    static let success = Color(light: 0x2E9E5B, dark: 0x3DD68C)
    static let warning = Color(light: 0xD98A06, dark: 0xF5B23D)
    static let danger = Color(light: 0xD93A3F, dark: 0xFF6369)
    static let info = Color(light: 0x3E63DD, dark: 0x7B93FF)

    // MARK: Surfaces
    static let canvas = Color(light: 0xF4F1EA, dark: 0x0A1418)
    static let surface = Color(light: 0xFFFFFF, dark: 0x12212A)
    static let surfaceRaised = Color(light: 0xFBFAF6, dark: 0x182B35)
    static let stroke = Color(light: 0x0B3440, dark: 0xFFFFFF).opacity(0.08)

    static let radius: CGFloat = 22
    static let smallRadius: CGFloat = 14

    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x0B3440), Color(hex: 0x145C6E), Color(hex: 0x1F7A8C)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let threadGradient = LinearGradient(
        colors: [Color(hex: 0xF4C430), Color(hex: 0xE8A317)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Stable accent for an arbitrary string (plant / client / style names), used for avatars and chart series.
    static func accent(for key: String) -> Color {
        let palette: [Color] = [
            Color(hex: 0x145C6E), Color(hex: 0xE8A317), Color(hex: 0x6E56CF), Color(hex: 0x2E9E5B),
            Color(hex: 0xD93A3F), Color(hex: 0x3E63DD), Color(hex: 0xC2410C), Color(hex: 0x0E7490),
        ]
        let hash = key.unicodeScalars.reduce(5381) { ($0 &<< 5) &+ $0 &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
            })
    }
}

// MARK: - Formatting

enum Fmt {
    static let currencyCode = "MXN"

    static func money(_ value: Double, compact: Bool = false) -> String {
        if compact, abs(value) >= 10_000 {
            return "$" + value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        }
        return value.formatted(.currency(code: currencyCode).precision(.fractionLength(0...2)))
    }

    static func int(_ value: Int) -> String { value.formatted(.number) }

    static func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)))
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func relativeDays(_ days: Int?) -> String {
        guard let days else { return "Sin fecha" }
        switch days {
        case ..<(-1): return "Vencido hace \(-days) días"
        case -1: return "Venció ayer"
        case 0: return "Vence hoy"
        case 1: return "Vence mañana"
        default: return "En \(days) días"
        }
    }
}
