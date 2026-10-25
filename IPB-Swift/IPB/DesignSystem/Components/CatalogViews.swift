import CoreData
import SwiftUI

/// Brand hero header used at the top of catalog detail screens.
struct DetailHero<Leading: View, Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    init(
        _ title: String, subtitle: String? = nil, @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 22) {
                leading
                titles
                Spacer(minLength: 16)
                trailing
            }
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 18) {
                    leading
                    titles
                }
                trailing
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Theme.brandGradient
                WeaveTexture(spacing: 12, ink: .white.opacity(0.06))
                RadialGradient(
                    colors: [Theme.thread.opacity(0.28), .clear], center: .topTrailing, startRadius: 10, endRadius: 420)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: Theme.brandDeep.opacity(0.25), radius: 20, y: 10)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if let subtitle {
                Text(subtitle).font(.callout).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
            }
        }
    }
}

/// White-on-brand figure used inside `DetailHero`.
struct HeroStat: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: Theme.smallRadius, style: .continuous))
    }
}

/// Compact icon + value + caption used on catalog cards.
struct CardStat: View {
    var symbol: String
    var value: String
    var label: String
    var tint: Color = Theme.brand

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Toolbar "+" button with ⌘N.
struct AddToolbarButton: ToolbarContent {
    var title: String
    var action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: action) {
                Label(title, systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel(title)
        }
    }
}

/// Row-style link used for orders / assignments lists inside detail screens.
struct CatalogRowCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 14) {
            content
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.smallRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).strokeBorder(Theme.stroke)
        }
        .contentShape(.rect)
    }
}

extension View {
    /// `confirmDelete` driven by an optional item rather than a Bool.
    func confirmDelete<Item>(
        _ title: String, item: Binding<Item?>, message: String? = nil, action: @escaping (Item) -> Void
    ) -> some View {
        confirmDelete(
            title,
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            message: message
        ) {
            if let value = item.wrappedValue { action(value) }
            item.wrappedValue = nil
        }
    }

    /// Standard scrolling catalog layout.
    func catalogScroll() -> some View {
        ScrollView {
            self
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 1_400)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
        .ipbScreenBackground()
    }
}

/// Case/diacritic-insensitive search over several fields.
enum CatalogSearch {
    static func matches(_ query: String, _ fields: [String?]) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        let haystack = fields.compactMap { $0 }.joined(separator: " ")
        return haystack.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

#if DEBUG
    extension View {
        /// Injects the demo store and the app's environment objects, signed in as `email`.
        @MainActor
        func catalogPreviewEnvironment(signedInAs email: String = "admin@ipb.mx") -> some View {
            let context = PersistenceController.preview.viewContext
            let session = Session(context: context, defaults: UserDefaults(suiteName: "ipb.preview.catalogs") ?? .standard)
            try? session.signIn(email: email, password: DemoSeeder.demoPassword)
            return
                self
                .overlay(alignment: .bottom) { ToastOverlay() }
                .tint(Theme.brand)
                .environment(\.managedObjectContext, context)
                .environment(session)
                .environment(ToastCenter())
                .environment(AppRouter())
                .environment(ConnectivityMonitor())
        }
    }

    enum CatalogPreviewData {
        static func first<T: NSManagedObject>(_ type: T.Type) -> T {
            PersistenceController.preview.viewContext.fetchAll(type).first!
        }
    }
#endif
