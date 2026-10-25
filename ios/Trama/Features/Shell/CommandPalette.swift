import CoreData
import SwiftUI

/// ⌘K universal search: jump to any section, cut, plant, client, supplier or style.
struct CommandPalette: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @Environment(Session.self) private var session
    @Environment(AppRouter.self) private var router

    @State private var query = ""

    struct Hit: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let tint: Color
        let action: () -> Void
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.title) { group in
                    if !group.hits.isEmpty {
                        Section(group.title) {
                            ForEach(group.hits) { hit in
                                Button {
                                    hit.action()
                                    dismiss()
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: hit.symbol)
                                            .foregroundStyle(hit.tint)
                                            .frame(width: 34, height: 34)
                                            .background(hit.tint.opacity(0.12), in: .rect(cornerRadius: 10, style: .continuous))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(hit.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                            if !hit.subtitle.isEmpty {
                                                Text(hit.subtitle).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if groups.allSatisfy(\.hits.isEmpty) {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(
                text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Busca cortes, listas, clientes, estilos…"
            )
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
        }
    }

    private var q: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    private var groups: [(title: String, hits: [Hit])] {
        let sections = session.role.sections
        var result: [(String, [Hit])] = []

        let sectionHits =
            sections
            .filter { q.isEmpty || $0.title.lowercased().contains(q) }
            .map { section in
                Hit(
                    id: "section-\(section.rawValue)", title: section.title, subtitle: section.group.title,
                    symbol: section.symbol, tint: Theme.brand
                ) { router.open(section) }
            }
        result.append((String(localized: "Ir a"), sectionHits))
        guard !q.isEmpty else { return result }

        if sections.contains(.production) {
            let assignments = context.fetchAll(Assignment.self).filter { $0.searchableText.contains(q) }.prefix(12)
            result.append(
                (
                    String(localized: "Cortes en producción"),
                    assignments.map { a in
                        Hit(
                            id: "a-\(a.objectID)", title: "\(a.title) · \(a.plantName)",
                            subtitle: "\(a.order?.clientName ?? "") · \(a.cuttingStatus.title)",
                            symbol: a.cuttingStatus.symbol, tint: a.cuttingStatus.tint
                        ) {
                            router.open(.production, pushing: Route.assignment(a.objectID))
                        }
                    }
                ))
        }
        if sections.contains(.orders) {
            let orders = context.fetchAll(CutOrder.self).filter { $0.searchableText.contains(q) }.prefix(12)
            result.append(
                (
                    String(localized: "Cortes"),
                    orders.map { o in
                        Hit(
                            id: "o-\(o.objectID)", title: String(localized: "\(o.displayCode) · Lista \(o.list ?? "—")"),
                            subtitle: "\(o.clientName) · \(o.assignmentState.title)",
                            symbol: "scissors", tint: o.assignmentState.tint
                        ) {
                            router.open(.orders, pushing: Route.order(o.objectID))
                        }
                    }
                ))
        }
        if sections.contains(.plants) {
            let plants = context.fetchAll(Plant.self).filter { ($0.name ?? "").lowercased().contains(q) }
            result.append(
                (
                    String(localized: "Plantas"),
                    plants.map { p in
                        Hit(
                            id: "p-\(p.objectID)", title: p.displayName,
                            subtitle: String(localized: "Capacidad \(Fmt.money(p.maxCapacity, compact: true))/mes"),
                            symbol: "building.2.fill", tint: Theme.accent(for: p.displayName)
                        ) {
                            router.open(.plants, pushing: Route.plant(p.objectID))
                        }
                    }
                ))
        }
        if sections.contains(.clients) {
            let clients = context.fetchAll(Client.self).filter {
                ($0.name ?? "").lowercased().contains(q) || $0.contactList.contains { ($0.name ?? "").lowercased().contains(q) }
            }
            result.append(
                (
                    String(localized: "Clientes"),
                    clients.map { c in
                        Hit(
                            id: "c-\(c.objectID)", title: c.displayName, subtitle: c.contactList.first?.name ?? "",
                            symbol: "person.2.fill", tint: Theme.accent(for: c.displayName)
                        ) {
                            router.open(.clients, pushing: Route.client(c.objectID))
                        }
                    }
                ))
        }
        if sections.contains(.suppliers) {
            let suppliers = context.fetchAll(Supplier.self).filter { ($0.name ?? "").lowercased().contains(q) }
            result.append(
                (
                    String(localized: "Proveedores"),
                    suppliers.map { s in
                        Hit(
                            id: "s-\(s.objectID)", title: s.displayName, subtitle: s.address ?? "",
                            symbol: "truck.box.fill", tint: Theme.accent(for: s.displayName)
                        ) {
                            router.open(.suppliers, pushing: Route.supplier(s.objectID))
                        }
                    }
                ))
        }
        if sections.contains(.styles) {
            let styles = context.fetchAll(Style.self).filter { ($0.name ?? "").lowercased().contains(q) }
            result.append(
                (
                    String(localized: "Estilos"),
                    styles.map { s in
                        Hit(
                            id: "st-\(s.objectID)", title: s.displayName, subtitle: String(localized: "\(s.orderList.count) cortes"),
                            symbol: "tshirt.fill", tint: Theme.accent(for: s.displayName)
                        ) {
                            router.open(.styles, pushing: Route.style(s.objectID))
                        }
                    }
                ))
        }
        return result
    }
}
