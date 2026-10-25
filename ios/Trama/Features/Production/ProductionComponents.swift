import CoreData
import SwiftUI

/// Days-left chip colored by urgency.
struct DaysLeftBadge: View {
    var date: Date?

    var body: some View {
        let days = UrgencyPolicy.daysLeft(until: date)
        Pill(text: Fmt.relativeDays(days), symbol: "calendar.badge.clock", tint: tint(days))
    }

    private func tint(_ days: Int?) -> Color {
        guard let days else { return .secondary }
        switch days {
        case ..<0: return Theme.danger
        case 0...3: return Theme.warning
        default: return Theme.success
        }
    }
}

struct CutStatusPill: View {
    var status: CutStatus
    var body: some View { Pill(text: status.title, symbol: status.symbol, tint: status.tint) }
}

/// Funnel of an assignment's garments through the plant: planned → cut → produced → … → shipped.
struct ProductionFunnel: View {
    var metrics: AssignmentMetrics

    private var stages: [(String, Int, String, Color)] {
        [
            (String(localized: "Planeadas"), metrics.quantity, "list.bullet.clipboard", Theme.brand),
            (String(localized: "Cortadas"), metrics.realCut, "scissors", Theme.warning),
            (String(localized: "Producidas"), metrics.produced, "gearshape.2", Theme.info),
            (String(localized: "En plancha"), metrics.ironing, "flame", Color(hex: 0xC2410C)),
            (String(localized: "En empaque"), metrics.packing, "shippingbox", Color(hex: 0x6E56CF)),
            (String(localized: "En bodega"), metrics.warehouse, "building.columns", Color(hex: 0x0E7490)),
            (String(localized: "Enviadas"), metrics.shipped, "paperplane.fill", Theme.success),
        ]
    }

    var body: some View {
        let top = Double(max(metrics.quantity, metrics.realCut, 1))
        VStack(alignment: .leading, spacing: 12) {
            ForEach(stages, id: \.0) { title, value, symbol, tint in
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                        .frame(width: 26)
                    Text(title)
                        .font(.subheadline)
                        .frame(width: 110, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tint.opacity(0.12))
                            Capsule()
                                .fill(tint.gradient)
                                .frame(width: max(value > 0 ? 6 : 0, geo.size.width * min(1, Double(value) / top)))
                        }
                    }
                    .frame(height: 12)
                    Text(Fmt.int(value))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                        .frame(width: 80, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .animation(.spring(duration: 0.5), value: metrics)
    }
}

/// Compact card for an assignment (used by the board, shipments and lists).
struct AssignmentCard: View {
    @ObservedObject var assignment: Assignment
    var showPlant = true
    var compact = false

    var body: some View {
        let metrics = assignment.metrics
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                SwatchImage(data: assignment.order?.style?.imageData, name: assignment.order?.styleName ?? "", cornerRadius: 12)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(assignment.title).font(.headline)
                    Text(assignment.order?.clientName ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if showPlant {
                    Text(assignment.plantName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent(for: assignment.plantName))
                        .lineLimit(1)
                }
            }
            if !compact {
                HStack(spacing: 14) {
                    Label(Fmt.int(Int(assignment.quantity)), systemImage: "number")
                    Label("\(metrics.toShip) por enviar", systemImage: "shippingbox")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ProgressView(value: metrics.shippingProgress)
                    .tint(metrics.isComplete ? Theme.success : Theme.brand)
            }
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
    }
}

/// Row for a cut order in lists.
struct OrderRow: View {
    @ObservedObject var order: CutOrder

    var body: some View {
        HStack(spacing: 16) {
            SwatchImage(data: order.style?.imageData, name: order.styleName, cornerRadius: 14)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(order.displayCode).font(.headline)
                    Text("Lista \(order.list ?? "—")").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("\(order.clientName) · \(order.garment ?? "") · \(order.styleName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Pill(text: order.assignmentState.title, symbol: nil, tint: order.assignmentState.tint)
                    DaysLeftBadge(date: order.clientDate)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 6) {
                Text(Fmt.money(order.revenue)).font(.headline.monospacedDigit())
                Text("\(order.remainingQuantity) de \(Int(order.quantity)) por asignar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(order.assignedQuantity), total: Double(max(order.quantity, 1)))
                    .frame(width: 160)
                    .tint(order.assignmentState.tint)
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}

/// Which assignments the current user may see (plant managers only see their plant).
extension Session {
    func visibleAssignments(_ all: some Sequence<Assignment>) -> [Assignment] {
        guard role == .plantManager else { return Array(all) }
        guard let plant = user?.plant else { return [] }
        return all.filter { $0.plant?.objectID == plant.objectID }
    }
}
