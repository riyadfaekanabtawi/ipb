import SwiftUI

/// Decimal text field that updates its `Double` binding on every keystroke.
/// `TextField(value:format:)` only commits on return/focus loss, which made the legacy
/// calculator feel broken; this parses the raw text instead. Empty input maps to 0.
struct LiveNumberField: View {
    var title: String
    var symbol: String?
    @Binding var value: Double
    var unit: String?
    var prompt: String = "0"

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField(prompt, text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($focused)
                if let unit {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
        } label: {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .onAppear { text = Self.display(value) }
        .onChange(of: text) { _, new in
            let parsed = Self.parse(new)
            if parsed != value { value = parsed }
        }
        .onChange(of: value) { _, new in
            // External resets (e.g. "Limpiar") must reach the text; typing keeps the user's raw text.
            if Self.parse(text) != new { text = Self.display(new) }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { text = Self.display(value) }
        }
        .accessibilityLabel(title)
        .accessibilityValue(text.isEmpty ? "vacío" : text)
    }

    /// Accepts "1,234.5", "1234,5" (single comma as decimal), "$ 12" and whitespace.
    static func parse(_ raw: String) -> Double {
        var cleaned = raw.filter { "0123456789.,-".contains($0) }
        if cleaned.contains(".") {
            cleaned.removeAll { $0 == "," }
        } else if cleaned.filter({ $0 == "," }).count == 1, let comma = cleaned.firstIndex(of: ","),
            cleaned.distance(from: comma, to: cleaned.endIndex) != 4
        {
            cleaned.replaceSubrange(comma...comma, with: ".")
        } else {
            cleaned.removeAll { $0 == "," }
        }
        return Double(cleaned) ?? 0
    }

    static func display(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...4)).grouping(.never))
    }
}
