import SwiftUI

struct StyleDetailView: View {
    @ObservedObject var style: Style

    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var zooming = false
    @State private var confirmingDelete = false

    var body: some View {
        let orders = style.orderList
        let distribution = style.plantDistribution

        VStack(alignment: .leading, spacing: 28) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    image.frame(width: 420)
                    summary(orders: orders, distribution: distribution)
                }
                HStack(alignment: .top, spacing: 20) {
                    image.frame(width: 280)
                    summary(orders: orders, distribution: distribution)
                }
                VStack(alignment: .leading, spacing: 24) {
                    image.frame(maxWidth: 360)
                    summary(orders: orders, distribution: distribution)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("Cortes con este estilo", subtitle: orders.isEmpty ? "Sin cortes" : "\(orders.count) cortes")
                if orders.isEmpty {
                    Text("Ningún corte usa este estilo todavía.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .card()
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(orders, id: \.objectID) { order in
                            NavigationLink(value: Route.order(order.objectID)) {
                                StyleOrderRow(order: order)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .catalogScroll()
        .navigationTitle(style.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Editar", systemImage: "pencil") { editing = true }
                    .keyboardShortcut("e", modifiers: .command)
                Menu {
                    Button("Eliminar estilo", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Más opciones")
            }
        }
        .sheet(isPresented: $editing) { StyleEditorSheet(style: style) }
        .fullScreenCover(isPresented: $zooming) {
            ZoomableImageViewer(data: style.imageData, title: style.displayName)
        }
        .confirmDelete(
            "¿Eliminar \(style.displayName)?", isPresented: $confirmingDelete,
            message: "Los cortes que lo usan quedarán sin estilo.", action: delete)
    }

    private var image: some View {
        Button {
            zooming = true
        } label: {
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay { SwatchImage(data: style.imageData, name: style.displayName, cornerRadius: 0) }
                .clipShape(.rect(cornerRadius: Theme.radius, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: .circle)
                        .padding(16)
                }
                .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ver imagen en pantalla completa")
    }

    private func summary(orders: [CutOrder], distribution: [(plant: Plant, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(style.displayName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if let created = style.createdAt {
                    Text("Registrado el \(Fmt.date(created))").foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: AdaptiveGrid.adaptive(min: 150, spacing: 14), spacing: 14) {
                KPITile(title: "Cortes", value: Fmt.int(orders.count), symbol: "scissors")
                KPITile(
                    title: "Prendas", value: Fmt.int(orders.reduce(0) { $0 + Int($1.quantity) }), symbol: "tshirt.fill",
                    tint: Theme.thread)
                KPITile(
                    title: "Valor", value: Fmt.money(orders.reduce(0) { $0 + $1.revenue }, compact: true), symbol: "banknote",
                    tint: Theme.success)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Asignado a plantas").font(.headline)
                if distribution.isEmpty {
                    Text("Aún no se asigna a ninguna planta.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    FlowRow(spacing: 8) {
                        ForEach(distribution, id: \.plant.objectID) { entry in
                            NavigationLink(value: Route.plant(entry.plant.objectID)) {
                                Pill(
                                    text: "\(entry.plant.displayName): \(entry.count) \(entry.count == 1 ? "asignación" : "asignaciones")",
                                    symbol: "building.2.fill", tint: Theme.accent(for: entry.plant.displayName))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func delete() {
        let name = style.displayName
        do {
            try session.service.delete(style)
            toasts.show("Estilo «\(name)» eliminado")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

private struct StyleOrderRow: View {
    @ObservedObject var order: CutOrder

    var body: some View {
        let state = order.assignmentState
        CatalogRowCard {
            VStack(alignment: .leading, spacing: 3) {
                Text(order.displayCode).font(.headline)
                Text(order.clientName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(Fmt.int(Int(order.quantity))) prendas").font(.subheadline.weight(.semibold)).monospacedDigit()
            Pill(text: state.title, symbol: nil, tint: state.tint)
        }
    }
}

#Preview("Detalle de estilo") {
    NavigationStack { StyleDetailView(style: CatalogPreviewData.first(Style.self)) }
        .catalogPreviewEnvironment()
}
