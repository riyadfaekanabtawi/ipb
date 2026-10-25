import Foundation

/// Loosely typed JSON value. The legacy Rails API was inconsistent (ids as numbers or strings,
/// quantities as strings, `null` everywhere), so mapping reads values leniently.
enum LegacyJSON: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: LegacyJSON])
    case array([LegacyJSON])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([LegacyJSON].self) {
            self = .array(a)
        } else {
            self = .object(try c.decode([String: LegacyJSON].self))
        }
    }

    /// Trimmed, non-empty text. Numbers render without a trailing ".0".
    var text: String? {
        switch self {
        case .string(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty || t == "<null>" ? nil : t
        case .number(let n):
            return n.rounded() == n ? String(Int64(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    var double: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s):
            let cleaned = s.filter { "0123456789.-".contains($0) }
            return Double(cleaned)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var int: Int? { double.map { Int($0.rounded()) } }
}

typealias LegacyRow = [String: LegacyJSON]

extension Dictionary where Key == String, Value == LegacyJSON {
    func text(_ key: String) -> String? { self[key]?.text }
    func double(_ key: String) -> Double? { self[key]?.double }
    func int(_ key: String) -> Int? { self[key]?.int }
    func date(_ key: String) -> Date? { LegacyDates.parse(self[key]?.text) }
}

enum LegacyDates {
    private static let dayFormats = ["dd-MM-yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "yyyy/MM/dd"]

    /// Legacy dates are mostly "dd-MM-yyyy" strings; some endpoints sent ISO dates or timestamps.
    static func parse(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.isLenient = false
        // Only the date part matters for "yyyy-MM-dd HH:mm:ss" style values.
        let datePart = String(raw.prefix(10))
        for format in dayFormats {
            f.dateFormat = format
            if let d = f.date(from: datePart) { return d }
        }
        return nil
    }
}
