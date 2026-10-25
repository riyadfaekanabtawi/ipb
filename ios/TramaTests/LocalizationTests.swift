import CoreData
import Foundation
import Testing

@testable import Trama

/// The app ships in Spanish (Mexico, source), English and Portuguese (Brazil).
@Suite("Localization")
struct LocalizationTests {
    private static let languages = ["en", "pt-BR"]

    /// Reads the String Catalog source next to this file (simulator tests can read the host file system).
    private static func catalog() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../Trama/Resources/Localizable.xcstrings")
            .standardizedFileURL
        let data = try Data(contentsOf: url)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Translated text of one localization: a plain string unit or every plural form.
    private static func values(of localization: [String: Any]) -> [String] {
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String,
            unit["state"] as? String == "translated"
        {
            return [value]
        }
        guard let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any],
            plural["other"] != nil
        else { return [] }
        return plural.values.compactMap { (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
    }

    /// The string unit, or the plural "other" form.
    private static func fullForm(of localization: [String: Any]) -> String? {
        if let unit = localization["stringUnit"] as? [String: Any] { return unit["value"] as? String }
        let other = ((localization["variations"] as? [String: Any])?["plural"] as? [String: Any])?["other"] as? [String: Any]
        return (other?["stringUnit"] as? [String: Any])?["value"] as? String
    }

    private static func specifiers(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(lld|ld|d|@|f)")
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { (text as NSString).substring(with: $0.range(at: 1)) }.sorted()
    }

    @Test func catalogUsesSpanishMexicoAsSource() throws {
        #expect(try Self.catalog()["sourceLanguage"] as? String == "es-MX")
    }

    @Test func everyKeyHasEnglishAndPortugueseTranslations() throws {
        let strings = try #require(try Self.catalog()["strings"] as? [String: [String: Any]])
        #expect(strings.count > 500)
        var missing: [String] = []
        var badSpecifiers: [String] = []
        for (key, entry) in strings where entry["shouldTranslate"] as? Bool != false {
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            for language in Self.languages {
                let values = localizations[language].map(Self.values(of:)) ?? []
                if values.isEmpty || values.contains(where: \.isEmpty) {
                    missing.append("\(language): \(key)")
                }
                // Plural "one" forms may drop the number ("tomorrow"), so only the full form is compared.
                if let full = localizations[language].flatMap(Self.fullForm(of:)), Self.specifiers(full) != Self.specifiers(key) {
                    badSpecifiers.append("\(language): \(key) → \(full)")
                }
            }
        }
        #expect(missing.isEmpty, "Untranslated: \(missing.sorted().prefix(20))")
        #expect(badSpecifiers.isEmpty, "Format specifiers differ: \(badSpecifiers.sorted().prefix(20))")
    }

    @Test func appBundleContainsAllLocalizations() {
        let localizations = Set(Bundle.main.localizations)
        #expect(localizations.isSuperset(of: ["es-MX", "en", "pt-BR"]))
    }

    @Test(arguments: [
        ("en_US", "Cutting board", "Plant calendar", "Cutting Manager"),
        ("pt_BR", "Quadro de corte", "Calendário das unidades", "Gerente de Corte"),
        ("es_MX", "Tablero de corte", "Calendario de plantas", "Gerente de cortes"),
    ])
    func terminology(locale: String, board: String, calendar: String, cutManager: String) {
        let bundle = L10n.bundle(for: Locale(identifier: locale))
        #expect(String(localized: "Tablero de corte", bundle: bundle) == board)
        #expect(String(localized: "Calendario de plantas", bundle: bundle) == calendar)
        #expect(String(localized: "Gerente de cortes", bundle: bundle) == cutManager)
    }

    @Test(arguments: [
        ("en_US", "1 garment", "11,200 garments"),
        ("pt_BR", "1 peça", "11.200 peças"),
        ("es_MX", "1 prenda", "11,200 prendas"),
    ])
    func pluralsFollowTheLocale(locale: String, one: String, many: String) {
        let locale = Locale(identifier: locale)
        let bundle = L10n.bundle(for: locale)
        func garments(_ n: Int) -> String {
            String(localized: "\(n) prendas", bundle: bundle, locale: locale).replacingOccurrences(of: "\u{202F}", with: " ")
        }
        #expect(garments(1) == one)
        #expect(garments(11_200) == many)
    }

    @Test func demoDataFollowsTheLanguageButKeepsRawValues() throws {
        for (language, plant, garment) in [
            ("en", "North Plant", "Skirt"), ("pt-BR", "Unidade Norte", "Saia"), ("es-MX", "Planta Norte", "Falda"),
        ] {
            let context = PersistenceController(inMemory: true).viewContext
            DemoSeeder.seed(into: context, language: language)
            let plants = context.fetchAll(Plant.self).compactMap(\.name)
            #expect(plants.contains(plant))
            #expect(context.fetchAll(CutOrder.self).contains { $0.code == "C-1042" && $0.garment == garment })
            let roles = Set(context.fetchAll(AppUser.self).compactMap(\.roleRaw))
            #expect(roles == Set(Role.allCases.map(\.rawValue)))
        }
        #expect(DemoSeeder.companyName(language: "en") == "Demo Textiles")
    }
}

/// `Fmt` keeps amounts in MXN and formats them with the user's locale.
@Suite("Fmt per locale")
struct FmtLocaleTests {
    /// ICU uses (narrow) no-break spaces; compare with plain spaces.
    private func plain(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private var sampleDate: Date {
        var components = DateComponents(year: 2026, month: 10, day: 25, hour: 12)
        components.calendar = Calendar(identifier: .gregorian)
        return components.date!
    }

    @Test func spanishMexico() {
        let es = Locale(identifier: "es_MX")
        #expect(plain(Fmt.money(1_800_000, compact: true, locale: es)) == "$1.8 M")
        #expect(plain(Fmt.money(272_000, locale: es)) == "$272,000")
        #expect(Fmt.int(11_200, locale: es) == "11,200")
        #expect(plain(Fmt.date(sampleDate, locale: es)) == "25 oct 2026")
        #expect(Fmt.relativeDays(4, locale: es) == "En 4 días")
    }

    @Test func english() {
        let en = Locale(identifier: "en_US")
        #expect(plain(Fmt.money(1_800_000, compact: true, locale: en)) == "MX$1.8M")
        #expect(plain(Fmt.money(272_000, locale: en)) == "MX$272,000")
        #expect(plain(Fmt.money(68, locale: en)) == "MX$68")
        #expect(Fmt.int(11_200, locale: en) == "11,200")
        #expect(Fmt.percent(0.38, locale: en) == "38%")
        #expect(Fmt.date(sampleDate, locale: en) == "Oct 25, 2026")
        #expect(Fmt.relativeDays(4, locale: en) == "In 4 days")
        #expect(Fmt.relativeDays(-3, locale: en) == "Overdue by 3 days")
        #expect(Fmt.relativeDays(nil, locale: en) == "No date")
    }

    @Test func portugueseBrazil() {
        let pt = Locale(identifier: "pt_BR")
        #expect(plain(Fmt.money(1_800_000, compact: true, locale: pt)) == "MX$ 1,8 mi")
        #expect(plain(Fmt.money(272_000, locale: pt)) == "MX$ 272.000")
        #expect(Fmt.int(11_200, locale: pt) == "11.200")
        #expect(plain(Fmt.number(2.5, locale: pt)) == "2,5")
        #expect(plain(Fmt.date(sampleDate, locale: pt)) == "25 de out. de 2026")
        #expect(Fmt.relativeDays(4, locale: pt) == "Em 4 dias")
    }

    @Test func monthLabelsFollowTheLocale() {
        #expect(MonthLabel.long(sampleDate, locale: Locale(identifier: "en_US")) == "October 2026")
        #expect(MonthLabel.long(sampleDate, locale: Locale(identifier: "pt_BR")) == "Outubro 2026")
        #expect(MonthLabel.long(sampleDate, locale: Locale(identifier: "es_MX")) == "Octubre 2026")
    }
}
