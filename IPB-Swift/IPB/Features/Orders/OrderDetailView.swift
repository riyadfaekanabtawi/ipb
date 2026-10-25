import CoreData
import SwiftUI

/// Cut order detail: summary, assignment progress, assignments per plant and the assign action.
struct OrderDetailView: View {
    @ObservedObject var order: CutOrder

    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @State private var assigning = false
    @State private var editing = false
    @State private var zoom = false
    @State private var unassigning: Assignment?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                HStack(alignment: .top, spacing: 20) {
                    details
                    progress
                }
                assignments
            }
            .padding(24)
            .frame(maxWidth: 1_200)
            .frame(maxWidth: .infinity)
        }
        .ipbScreenBackground()
        .navigationTitle("Corte \(order.displayCode)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editing = true
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                Button {
                    assigning = true
                } label: {
                    Label("Asignar a planta", systemImage: "arrow.triangle.branch")
                }
                .disabled(order.remainingQuantity == 0)
                .keyboardShortcut("a", modifiers: .command)
            }
        }
        .sheet(isPresented: $assigning) { AssignSheet(order: order) }
        .sheet(isPresented: $editing) { OrderEditorSheet(order: order) }
        .fullScreenCover(isPresented: $zoom) { ZoomableImageViewer(data: order.style?.imageData, title: order.styleName) }
        .confirmDelete(
            "¿Quitar esta asignación?", isPresented: Binding(get: { unassigning != nil }, set: { if !$0 { unassigning = nil } }),
            message: "Las prendas vuelven a quedar por asignar."
        ) {
            guard let a = unassigning else { return }
            do {
                try session.service.unassign(a)
                toasts.show("Asignación eliminada")
            } catch { toasts.error(error) }
            unassigning = nil
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            Button {
                zoom = true
            } label: {
                SwatchImage(data: order.style?.imageData, name: order.styleName, cornerRadius: 20)
                    .frame(width: 120, height: 120)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ver imagen del estilo")
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(order.displayCode).font(.system(size: 34, weight: .bold, design: .rounded))
                    Pill(text: order.assignmentState.title, symbol: nil, tint: order.assignmentState.tint)
                }
                Text("\(order.clientName) · Lista \(order.list ?? "—")").font(.title3).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Pill(text: order.garment ?? "Prenda", symbol: "tshirt", tint: Theme.brand)
                    Pill(text: order.styleName, symbol: "paintpalette", tint: Theme.accent(for: order.styleName))
                    DaysLeftBadge(date: order.clientDate)
                }
            }
            Spacer()
        }
        .card()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Detalle")
            InfoRow(label: "Cantidad", value: Fmt.int(Int(order.quantity)), symbol: "number")
            InfoRow(label: "Precio unitario", value: Fmt.money(order.unitPrice), symbol: "tag")
            InfoRow(label: "Ingreso total", value: Fmt.money(order.revenue), symbol: "banknote")
            InfoRow(label: "Fecha IPB", value: Fmt.date(order.ipbDate), symbol: "calendar")
            InfoRow(label: "Fecha cliente", value: Fmt.date(order.clientDate), symbol: "calendar.badge.clock")
            if let editedBy = order.editedBy {
                InfoRow(label: "Editado por", value: editedBy, symbol: "person")
            }
            if let notes = order.notes, !notes.isEmpty {
                Text(notes).font(.callout).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var progress: some View {
        let ratio = order.quantity > 0 ? Double(order.assignedQuantity) / Double(order.quantity) : 0
        return VStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: ratio, tint: order.assignmentState.tint, lineWidth: 14)
                VStack(spacing: 2) {
                    Text(Fmt.percent(ratio)).font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("asignado").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            VStack(spacing: 4) {
                Text("\(Fmt.int(order.remainingQuantity)) prendas por asignar").font(.headline)
                Text("de \(Fmt.int(Int(order.quantity)))").font(.subheadline).foregroundStyle(.secondary)
            }
            Button {
                assigning = true
            } label: {
                Label("Asignar a planta", systemImage: "arrow.triangle.branch")
            }
            .buttonStyle(.ipbPrimary)
            .disabled(order.remainingQuantity == 0)
        }
        .frame(width: 300)
        .card()
    }

    private var assignments: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Asignaciones", subtitle: "Dónde se está produciendo este corte")
            if order.assignmentList.isEmpty {
                ContentUnavailableView(
                    "Sin asignar", systemImage: "building.2",
                    description: Text("Asigna prendas a una planta según su capacidad mensual."))
            } else {
                ForEach(order.assignmentList) { assignment in
                    NavigationLink(value: Route.assignment(assignment.objectID)) {
                        AssignmentLine(assignment: assignment)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Quitar asignación", systemImage: "arrow.uturn.backward", role: .destructive) { unassigning = assignment }
                    }
                }
            }
        }
        .card()
    }
}

private struct AssignmentLine: View {
    @ObservedObject var assignment: Assignment

    var body: some View {
        let metrics = assignment.metrics
        HStack(spacing: 14) {
            AvatarView(name: assignment.plantName, size: 44, symbol: "building.2.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.plantName).font(.headline)
                Text("\(Fmt.int(Int(assignment.quantity))) prendas · \(Fmt.money(metrics.revenue)) · \(Fmt.date(assignment.scheduledDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CutStatusPill(status: assignment.cuttingStatus)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Theme.surfaceRaised, in: .rect(cornerRadius: 14, style: .continuous))
        .contentShape(.rect)
    }
}
