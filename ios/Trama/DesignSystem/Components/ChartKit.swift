import SwiftUI

// Shared building blocks for chart cards (dashboard, reports, plants).

extension Locale {
    /// UI copy is Spanish (Mexico) regardless of the device language, so dates in headings match it.
    static let esMX = Locale(identifier: "es_MX")
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

enum MonthLabel {
    /// "Octubre 2026"
    static func long(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(.esMX)).replacingOccurrences(of: " de ", with: " ").capitalizedFirst
    }

    /// "oct"
    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(.esMX)).replacingOccurrences(of: ".", with: "")
    }

    /// "Sábado, 24 de octubre de 2026"
    static func fullDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(.esMX)).capitalizedFirst
    }
}

/// Card with a section header and arbitrary chart content.
struct ChartCard<Content: View, Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    init(
        _ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title, subtitle: subtitle) { trailing }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// "‹ Octubre 2026 ›" stepper over calendar months.
struct MonthStepper: View {
    @Binding var month: Date
    var calendar: Calendar = .current

    var body: some View {
        HStack(spacing: 4) {
            stepButton(-1, symbol: "chevron.left", label: "Mes anterior")
            Text(MonthLabel.long(month))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 132)
                .onTapGesture(count: 2) { set(calendar.startOfMonth(for: .now)) }
                .accessibilityLabel("Mes seleccionado: \(MonthLabel.long(month))")
                .accessibilityHint("Toca dos veces para volver al mes actual")
            stepButton(1, symbol: "chevron.right", label: "Mes siguiente")
        }
        .padding(4)
        .background(Color.primary.opacity(0.05), in: .capsule)
    }

    private func stepButton(_ delta: Int, symbol: String, label: String) -> some View {
        Button {
            if let next = calendar.date(byAdding: .month, value: delta, to: month) { set(next) }
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 30)
                .background(Theme.surface, in: .circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.brand)
        .accessibilityLabel(label)
    }

    private func set(_ date: Date) {
        withAnimation(.spring(duration: 0.4)) { month = calendar.startOfMonth(for: date) }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// Colored dot + title + value, for chart legends.
struct LegendRow: View {
    var color: Color
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color.gradient).frame(width: 10, height: 10)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

/// Compact empty state for cards (ContentUnavailableView is too tall inside a card).
struct CardEmptyState: View {
    var title: String
    var symbol: String
    var message: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.brand.opacity(0.6))
            Text(title).font(.subheadline.weight(.semibold))
            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
