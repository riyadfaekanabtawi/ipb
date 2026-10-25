import CoreData
import SwiftUI

/// Kanban of assignments by cutting status (legacy "Análisis" screen with 3 lists).
/// Cards can be dragged between columns; each move updates the assignment's single cut report.
struct CutBoardView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [SortDescriptor(\Assignment.scheduledDate)]) private var assignments: FetchedResults<Assignment>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Plant.name)]) private var plants: FetchedResults<Plant>

    @State private var query = ""
    @State private var plantFilter: Plant?
    @State private var hideShipped = true
    @State private var targeted: CutStatus?

    private var canMove: Bool { session.role.canEdit(.cut) }

    private var visible: [Assignment] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return session.visibleAssignments(assignments).filter { a in
            (plantFilter == nil || a.plant == plantFilter)
                && (q.isEmpty || a.searchableText.contains(q))
                && (!hideShipped || !a.metrics.isComplete)
        }
    }

    var body: some View {
        let grouped = Dictionary(grouping: visible, by: \.cuttingStatus)
        GeometryReader { geo in
            // Three columns fill the detail width; below 220pt each, the board scrolls sideways.
            let width = max(220, (geo.size.width - 48 - 36) / 3)
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(CutStatus.allCases) { status in
                        column(status, items: grouped[status] ?? [], width: width)
                    }
                }
                .padding(24)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .ipbScreenBackground()
        .searchable(text: $query, prompt: "Buscar corte, cliente, planta…")
        .navigationTitle("Tablero de corte")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $hideShipped) { Label("Ocultar enviados", systemImage: "eye.slash") }
                    .toggleStyle(.button)
                Menu {
                    Picker("Planta", selection: $plantFilter) {
                        Text("Todas las plantas").tag(Plant?.none)
                        ForEach(plants) { Text($0.displayName).tag(Optional($0)) }
                    }
                } label: {
                    Label(plantFilter?.displayName ?? "Todas las plantas", systemImage: "building.2")
                }
            }
        }
    }

    private func column(_ status: CutStatus, items: [Assignment], width: CGFloat) -> some View {
        let garments = items.reduce(0) { $0 + Int($1.quantity) }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: status.symbol)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(status.tint.gradient, in: .rect(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(status.title).font(.headline)
                    Text("\(items.count) \(items.count == 1 ? "corte" : "cortes") · \(Fmt.int(garments)) prendas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
            }

            if items.isEmpty {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundStyle(status.tint.opacity(0.4))
                    .frame(height: 120)
                    .overlay(Text(canMove ? "Arrastra cortes aquí" : "Sin cortes").font(.callout).foregroundStyle(.secondary))
            }

            LazyVStack(spacing: 12) {
                ForEach(items) { assignment in
                    NavigationLink(value: Route.assignment(assignment.objectID)) {
                        BoardCard(assignment: assignment)
                    }
                    .buttonStyle(.plain)
                    .draggable(assignment.objectID.uriRepresentation().absoluteString) {
                        BoardCard(assignment: assignment).frame(width: 300).opacity(0.9)
                    }
                    .contextMenu {
                        if canMove {
                            ForEach(CutStatus.allCases.filter { $0 != status }) { target in
                                Button("Mover a \(target.title)", systemImage: target.symbol) { move(assignment, to: target) }
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: width)
        .frame(minHeight: 500, alignment: .top)
        .background(status.tint.opacity(targeted == status ? 0.16 : 0.06), in: .rect(cornerRadius: Theme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(status.tint.opacity(targeted == status ? 0.8 : 0.15), lineWidth: targeted == status ? 2 : 1)
        }
        .animation(.spring(duration: 0.25), value: targeted)
        .dropDestination(for: String.self) { uris, _ in
            guard canMove else {
                toasts.show("Solo administradores y gerentes de cortes pueden mover cortes.", style: .info)
                return false
            }
            for uri in uris {
                if let url = URL(string: uri),
                    let id = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
                    let assignment = context.existing(Assignment.self, id),
                    assignment.cuttingStatus != status
                {
                    move(assignment, to: status)
                }
            }
            return true
        } isTargeted: { isTargeted in
            targeted = isTargeted ? status : (targeted == status ? nil : targeted)
        }
    }

    private func move(_ assignment: Assignment, to status: CutStatus) {
        do {
            try withAnimation(.spring(duration: 0.35)) {
                try session.service.move(assignment, to: status)
            }
            toasts.show("\(assignment.title) → \(status.title)")
        } catch {
            toasts.error(error)
        }
    }
}

private struct BoardCard: View {
    @ObservedObject var assignment: Assignment

    var body: some View {
        let metrics = assignment.metrics
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.title).font(.headline)
                    Text(assignment.order?.clientName ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                SwatchImage(data: assignment.order?.style?.imageData, name: assignment.order?.styleName ?? "", cornerRadius: 10)
                    .frame(width: 40, height: 40)
            }
            FlowRow(spacing: 6) {
                Pill(text: assignment.plantName, symbol: "building.2", tint: Theme.accent(for: assignment.plantName))
                DaysLeftBadge(date: assignment.order?.clientDate)
            }
            HStack {
                Label(Fmt.int(Int(assignment.quantity)), systemImage: "list.bullet.clipboard")
                Spacer()
                Label(metrics.realCut > 0 ? Fmt.int(metrics.realCut) : "—", systemImage: "scissors")
                    .foregroundStyle(metrics.realCut > 0 ? .primary : .secondary)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .contentShape(.rect)
    }
}

#Preview {
    let persistence = PersistenceController.preview
    return NavigationStack { CutBoardView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(Session(context: persistence.viewContext))
        .environment(ToastCenter())
        .environment(AppRouter())
}
