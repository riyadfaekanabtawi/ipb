import SwiftUI
import UIKit

/// Trama design tokens. Palette comes from weaving: a deep petrol-teal warp and a
/// thread-spool yellow weft, on warm "linen" neutrals.
/// Name of the customer company shown in the app (set during onboarding or in Ajustes).
enum Brand {
    static let productName = "Trama"
    static var tagline: String { String(localized: "Control de producción textil") }
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

/// Locale-aware formatting. Amounts are always stored in MXN; only their presentation follows the
/// user's locale ("$1.8 M" in es-MX, "MX$1.8M" in en, "MX$ 1,8 mi" in pt-BR). Every function takes a
/// `locale` (default: the app's current locale) so tests can pin one.
enum Fmt {
    static let currencyCode = "MXN"

    static func money(_ value: Double, compact: Bool = false, locale: Locale = .autoupdatingCurrent) -> String {
        let style = FloatingPointFormatStyle<Double>.Currency(code: currencyCode, locale: locale)
        if compact, abs(value) >= 10_000 {
            // Compact number placed where the locale puts the digits of a currency amount ("$0", "MX$0", "MX$ 0").
            // (ICU's compact currency is iOS 18+ and yields "1.8 M$" in es-MX.)
            let number = value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)).locale(locale))
            return 0.0.formatted(style.precision(.fractionLength(0))).replacingOccurrences(of: "0", with: number)
        }
        return value.formatted(style.precision(.fractionLength(0...2)))
    }

    static func int(_ value: Int, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(.number.locale(locale))
    }

    static func number(_ value: Double, digits: Int = 1, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
    }

    static func percent(_ value: Double, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    static func date(_ date: Date?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    static func shortDate(_ date: Date?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    static func relativeDays(_ days: Int?, locale: Locale = .autoupdatingCurrent) -> String {
        let bundle = L10n.bundle(for: locale)
        guard let days else { return String(localized: "Sin fecha", bundle: bundle, locale: locale) }
        switch days {
        case ..<(-1): return String(localized: "Vencido hace \(-days) días", bundle: bundle, locale: locale)
        case -1: return String(localized: "Venció ayer", bundle: bundle, locale: locale)
        case 0: return String(localized: "Vence hoy", bundle: bundle, locale: locale)
        case 1: return String(localized: "Vence mañana", bundle: bundle, locale: locale)
        default: return String(localized: "En \(days) días", bundle: bundle, locale: locale)
        }
    }
}

// MARK: - Localization helpers

/// The app ships in Spanish (Mexico, source language), English and Portuguese (Brazil).
enum L10n {
    /// Language the app is running in ("es-MX", "en" or "pt-BR").
    static var language: String { Bundle.main.preferredLocalizations.first ?? "es-MX" }

    /// The `.lproj` bundle matching `locale`, so a pinned locale also pins the translation (tests).
    /// Falls back to the main bundle, which resolves the user's language.
    static func bundle(for locale: Locale) -> Bundle {
        guard locale != .autoupdatingCurrent, let code = locale.language.languageCode?.identifier else { return .main }
        let region = locale.region?.identifier
        let candidates = [region.map { "\(code)-\($0)" }, code, code == "es" ? "es-MX" : nil, code == "pt" ? "pt-BR" : nil]
        for name in candidates.compactMap({ $0 }) {
            if let path = Bundle.main.path(forResource: name, ofType: "lproj"), let bundle = Bundle(path: path) { return bundle }
        }
        return .main
    }
}

extension LocalizedStringKey {
    /// Shows user data (names, codes) or text that is already localized as-is, where an API takes a key.
    static func verbatim(_ text: String) -> LocalizedStringKey { "\(text)" }

    static func verbatim(_ text: String?) -> LocalizedStringKey? { text.map { "\($0)" } }
}
