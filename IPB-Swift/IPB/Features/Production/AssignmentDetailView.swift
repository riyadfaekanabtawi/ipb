import CoreData
import SwiftUI

/// Detail of a cut assigned to a plant: live production funnel, report timeline and
/// role-aware report actions (legacy CutDetailViewController).
struct AssignmentDetailView: View {
    @ObservedObject var assignment: Assignment

    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @State private var editor: ReportEditor?
    @State private var zoom = false
    @State private var deleting: ProductionReport?
    @State private var kindFilter: ReportKind?

    enum ReportEditor: Identifiable {
        case new(ReportKind)
        case edit(ProductionReport)
        var id: String {
            switch self {
            case .new(let kind): "new-\(kind.rawValue)"
            case .edit(let report): "edit-\(report.objectID)"
            }
        }
    }

    var body: some View {
        let metrics = assignment.metrics
        ScrollView {
            VStack(spacing: 20) {
                header(metrics)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        funnel(metrics)
                        stats(metrics).frame(width: 340)
                    }
                    VStack(spacing: 20) {
                        funnel(metrics)
                        stats(metrics)
                    }
                }
                timeline
            }
            .padding(24)
            .frame(maxWidth: 1_200)
            .frame(maxWidth: .infinity)
        }
        .ipbScreenBackground()
        .navigationTitle("Corte \(assignment.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { addMenu }
        }
        .sheet(item: $editor) { editor in
            switch editor {
            case .new(let kind): ReportEditorSheet(assignment: assignment, kind: kind, report: nil)
            case .edit(let report): ReportEditorSheet(assignment: assignment, kind: report.kind, report: report)
            }
        }
        .fullScreenCover(isPresented: $zoom) {
            ZoomableImageViewer(data: assignment.order?.style?.imageData, title: assignment.order?.styleName ?? "Estilo")
        }
        .confirmDelete("¿Eliminar este reporte?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            guard let report = deleting else { return }
            do {
                try session.service.delete(report)
                toasts.show("Reporte eliminado")
            } catch { toasts.error(error) }
            deleting = nil
        }
    }

    // MARK: Sections

    private func header(_ metrics: AssignmentMetrics) -> some View {
        HStack(spacing: 20) {
            Button {
                zoom = true
            } label: {
                SwatchImage(data: assignment.order?.style?.imageData, name: assignment.order?.styleName ?? "", cornerRadius: 20)
                    .frame(width: 110, height: 110)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ver imagen del estilo")

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(assignment.title).font(.system(size: 32, weight: .bold, design: .rounded))
                    CutStatusPill(status: assignment.cuttingStatus)
                }
                Text("\(assignment.order?.clientName ?? "") · Lista \(assignment.order?.list ?? "—") · \(assignment.order?.garment ?? "")")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Pill(text: assignment.plantName, symbol: "building.2.fill", tint: Theme.accent(for: assignment.plantName))
                    Pill(text: "Producción \(Fmt.date(assignment.scheduledDate))", symbol: "calendar", tint: Theme.brand)
                    DaysLeftBadge(date: assignment.order?.clientDate)
                }
            }
            Spacer()
            ZStack {
                ProgressRing(progress: metrics.shippingProgress, tint: metrics.isComplete ? Theme.success : Theme.brand, lineWidth: 12)
                VStack(spacing: 0) {
                    Text(Fmt.percent(metrics.shippingProgress)).font(.title2.bold())
                    Text("enviado").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 104, height: 104)
        }
        .card()
    }

    private func funnel(_ metrics: AssignmentMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Avance de producción", subtitle: "Último reporte de planta, corte real y envíos acumulados")
            ProductionFunnel(metrics: metrics)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func stats(_ metrics: AssignmentMetrics) -> some View {
        VStack(spacing: 14) {
            InfoRow(label: "Por enviar", value: Fmt.int(metrics.toShip), symbol: "shippingbox")
            InfoRow(label: "Operarios", value: Fmt.int(metrics.operators), symbol: "person.3")
            InfoRow(label: "Faltas", value: Fmt.int(metrics.absences), symbol: "person.fill.xmark")
            InfoRow(label: "Precio unitario", value: Fmt.money(metrics.unitPrice), symbol: "tag")
            InfoRow(label: "Ingreso", value: Fmt.money(metrics.revenue), symbol: "banknote")
            if let order = assignment.order {
                NavigationLink(value: Route.order(order.objectID)) {
                    Label("Ver corte completo", systemImage: "arrow.up.forward.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .card()
    }

    private var timeline: some View {
        let reports = assignment.reportList.filter { kindFilter == nil || $0.kind == kindFilter }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Reportes", subtitle: "\(assignment.reportList.count) en total") {
                Picker("Tipo", selection: $kindFilter) {
                    Text("Todos").tag(ReportKind?.none)
                    ForEach(ReportKind.allCases) { Text($0.shortTitle).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
                .frame(width: 340)
            }
            if reports.isEmpty {
                ContentUnavailableView {
                    Label("Sin reportes", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Los gerentes cargan aquí el avance de planta, el corte real y los envíos.")
                } actions: {
                    addMenu.buttonStyle(.borderedProminent)
                }
            }
            ForEach(reports) { report in
                ReportRow(report: report, canEdit: session.role.canEdit(report.kind)) {
                    editor = .edit(report)
                } onDelete: {
                    deleting = report
                }
            }
        }
        .card()
    }

    /// "+" menu offering only the report kinds this role may create. The cut report is unique,
    /// so once it exists the menu offers to edit it instead.
    private var addMenu: some View {
        let kinds = session.role.creatableReports
        return Menu {
            ForEach(kinds) { kind in
                if kind == .cut, let existing = assignment.cutReport {
                    Button("Editar reporte de corte", systemImage: "pencil") { editor = .edit(existing) }
                } else {
                    Button(kind.title, systemImage: kind.symbol) { editor = .new(kind) }
                }
            }
        } label: {
            Label("Cargar reporte", systemImage: "plus")
        } primaryAction: {
            if kinds.count == 1, let kind = kinds.first {
                if kind == .cut, let existing = assignment.cutReport { editor = .edit(existing) } else { editor = .new(kind) }
            }
        }
        .disabled(kinds.isEmpty)
    }
}

private struct ReportRow: View {
    @ObservedObject var report: ProductionReport
    var canEdit: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: report.kind.symbol)
                .font(.headline)
                .foregroundStyle(report.kind.tint)
                .frame(width: 44, height: 44)
                .background(report.kind.tint.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(report.kind.title).font(.headline)
                Text(report.summary).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(report.createdAt?.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)) ?? "—")
                    .font(.subheadline.weight(.medium))
                Text(
                    [report.createdAt?.formatted(.dateTime.hour().minute()), report.authorName].compactMap { $0 }.joined(separator: " · ")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if canEdit {
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Theme.surfaceRaised, in: .rect(cornerRadius: 14, style: .continuous))
        .contentShape(.rect)
        .onTapGesture { if canEdit { onEdit() } }
        .contextMenu {
            if canEdit {
                Button("Editar", systemImage: "pencil", action: onEdit)
                Button("Eliminar", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(canEdit ? .isButton : [])
    }
}

#Preview {
    let persistence = PersistenceController.preview
    let assignment = persistence.viewContext.fetchAll(Assignment.self).first!
    return NavigationStack { AssignmentDetailView(assignment: assignment) }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(Session(context: persistence.viewContext))
        .environment(ToastCenter())
        .environment(AppRouter())
}
