import CoreData
import SwiftUI

/// "Envíos urgentes": cuts with garments still to ship whose client date is close or past.
/// The legacy server decided urgency; here the window is a setting (default 7 days).
struct UrgentShipmentsView: View {
    @Environment(Session.self) private var session
    @FetchRequest(sortDescriptors: []) private var assignments: FetchedResults<Assignment>
    @AppStorage("settings.urgencyWindowDays") private var urgencyWindow = 7
    @State private var shipping: Assignment?

    var body: some View {
        let urgent = session.visibleAssignments(assignments)
            .filter { $0.isUrgent(windowDays: urgencyWindow) }
            .sorted { ($0.order?.clientDate ?? .distantFuture) < ($1.order?.clientDate ?? .distantFuture) }
        let overdue = urgent.filter { (UrgencyPolicy.daysLeft(until: $0.order?.clientDate) ?? 0) < 0 }
        let upcoming = urgent.filter { (UrgencyPolicy.daysLeft(until: $0.order?.clientDate) ?? 0) >= 0 }
        let garments = urgent.reduce(0) { $0 + $1.metrics.toShip }

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    KPITile(
                        title: "Envíos urgentes", value: Fmt.int(urgent.count), symbol: "exclamationmark.triangle.fill", tint: Theme.warning
                    )
                    KPITile(title: "Vencidos", value: Fmt.int(overdue.count), symbol: "clock.badge.exclamationmark", tint: Theme.danger)
                    KPITile(title: "Prendas por enviar", value: Fmt.int(garments), symbol: "shippingbox.fill", tint: Theme.brand)
                }

                if urgent.isEmpty {
                    ContentUnavailableView(
                        "No hay envíos urgentes", systemImage: "checkmark.seal.fill",
                        description: Text("Ningún corte con prendas pendientes vence en los próximos \(urgencyWindow) días.")
                    )
                    .padding(.top, 60)
                }
                if !overdue.isEmpty { group("Vencidos", tint: Theme.danger, items: overdue) }
                if !upcoming.isEmpty { group("Próximos \(urgencyWindow) días", tint: Theme.warning, items: upcoming) }
            }
            .padding(24)
        }
        .ipbScreenBackground()
        .navigationTitle("Envíos urgentes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Stepper("Ventana: \(urgencyWindow) días", value: $urgencyWindow.animation(), in: 1...30)
                    Picker("Ventana", selection: $urgencyWindow.animation()) {
                        ForEach([3, 7, 14, 30], id: \.self) { Text("\($0) días").tag($0) }
                    }
                } label: {
                    Label("Ventana: \(urgencyWindow) días", systemImage: "clock.badge.exclamationmark")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Entregas dentro de este plazo o vencidas se consideran urgentes")
            }
        }
        .sheet(item: $shipping) { ReportEditorSheet(assignment: $0, kind: .shipment, report: nil) }
    }

    private func group(_ title: String, tint: Color, items: [Assignment]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 10, height: 10)
                Text(title).font(.title3.bold())
                Text("\(items.count)").font(.title3).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: AdaptiveGrid.adaptive(min: 380), spacing: 16) {
                ForEach(items) { assignment in
                    ShipmentCard(assignment: assignment, canShip: session.role.canEdit(.shipment)) {
                        shipping = assignment
                    }
                }
            }
        }
    }
}

private struct ShipmentCard: View {
    @ObservedObject var assignment: Assignment
    var canShip: Bool
    var ship: () -> Void

    var body: some View {
        let metrics = assignment.metrics
        let days = UrgencyPolicy.daysLeft(until: assignment.order?.clientDate)
        NavigationLink(value: Route.assignment(assignment.objectID)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Text(days.map { "\(abs($0))" } ?? "—")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                        Text((days ?? 0) < 0 ? "días tarde" : "días")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle((days ?? 0) < 0 ? Theme.danger : Theme.warning)
                    .frame(width: 76, height: 76)
                    .background(
                        ((days ?? 0) < 0 ? Theme.danger : Theme.warning).opacity(0.12), in: .rect(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.title).font(.title3.bold())
                        Text(assignment.order?.clientName ?? "").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Pill(text: assignment.plantName, symbol: "building.2", tint: Theme.accent(for: assignment.plantName))
                            Pill(text: "Entrega \(Fmt.shortDate(assignment.order?.clientDate))", symbol: "calendar", tint: .secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(Fmt.int(metrics.shipped)) de \(Fmt.int(metrics.shippingBase)) enviadas")
                        Spacer()
                        Text("\(Fmt.int(metrics.toShip)) por enviar").fontWeight(.semibold)
                    }
                    .font(.caption)
                    ProgressView(value: metrics.shippingProgress).tint(Theme.brand)
                }
                HStack {
                    Label(Fmt.money(metrics.revenue), systemImage: "banknote").font(.subheadline.weight(.medium))
                    Spacer()
                    if canShip {
                        Button(action: ship) { Label("Registrar envío", systemImage: "paperplane.fill") }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.brand)
                    }
                }
            }
            .card(padding: 18)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let persistence = PersistenceController.preview
    return NavigationStack { UrgentShipmentsView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(Session(context: persistence.viewContext))
        .environment(ToastCenter())
        .environment(AppRouter())
}
