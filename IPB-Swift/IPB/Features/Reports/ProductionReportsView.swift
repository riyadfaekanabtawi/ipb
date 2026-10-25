import CoreData
import SwiftUI
import UniformTypeIdentifiers

/// One flattened, sortable row per assignment. Built once per render from Core Data.
struct ProductionRow: Identifiable, Hashable {
    let id: NSManagedObjectID
    let code: String
    let list: String
    let client: String
    let style: String
    let garment: String
    let plant: String
    let status: CutStatus
    let quantity: Int
    let realCut: Int
    let produced: Int
    let ironing: Int
    let packing: Int
    let warehouse: Int
    let shipped: Int
    let toShip: Int
    let revenue: Double
    let ipbDate: Date
    let clientDate: Date
    let metrics: AssignmentMetrics

    init(_ a: Assignment) {
        let m = a.metrics
        id = a.objectID
        code = a.order?.displayCode ?? "—"
        list = a.order?.list ?? ""
        client = a.order?.clientName ?? ""
        style = a.order?.styleName ?? ""
        garment = a.order?.garment ?? ""
        plant = a.plantName
        status = a.cuttingStatus
        quantity = m.quantity
        realCut = m.realCut
        produced = m.produced
        ironing = m.ironing
        packing = m.packing
        warehouse = m.warehouse
        shipped = m.shipped
        toShip = m.toShip
        revenue = m.revenue
        ipbDate = a.order?.ipbDate ?? .distantPast
        clientDate = a.order?.clientDate ?? .distantFuture
        metrics = m
    }

    static func == (l: Self, r: Self) -> Bool { l.id == r.id && l.metrics == r.metrics && l.status == r.status }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var statusTitle: String { status.title }
}

/// "Reportes de producción": every cut in production with filters and totals
/// (legacy ReportsViewController + filterCuts + getTotals).
struct ProductionReportsView: View {
    @Environment(Session.self) private var session
    @Environment(AppRouter.self) private var router

    @FetchRequest(sortDescriptors: [SortDescriptor(\Assignment.scheduledDate, order: .reverse)]) private var assignments:
        FetchedResults<Assignment>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Plant.name)]) private var plants: FetchedResults<Plant>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Client.name)]) private var clients: FetchedResults<Client>

    @State private var query = ""
    @State private var plant: Plant?
    @State private var client: Client?
    @State private var status: CutStatus?
    @State private var onlyPending = false
    @State private var useDateRange = false
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var to = Calendar.current.date(byAdding: .month, value: 2, to: .now) ?? .now
    @State private var sortKey: SortKey = .clientDate
    @State private var sortDescending = false
    @State private var showDateFilter = false

    private var isPlantManager: Bool { session.role == .plantManager }

    private var rows: [ProductionRow] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return session.visibleAssignments(assignments)
            .filter { a in
                (plant == nil || a.plant == plant)
                    && (client == nil || a.order?.client == client)
                    && (status == nil || a.cuttingStatus == status)
                    && (q.isEmpty || a.searchableText.contains(q))
                    && (!useDateRange || (a.order?.clientDate).map { $0 >= Calendar.current.startOfDay(for: from) && $0 <= to } ?? false)
            }
            .map(ProductionRow.init)
            .filter { !onlyPending || $0.toShip > 0 }
            .sorted(using: sortKey.comparator(descending: sortDescending))
    }

    private var hasFilters: Bool {
        plant != nil || client != nil || status != nil || onlyPending || useDateRange || !query.isEmpty
    }

    var body: some View {
        let rows = self.rows
        let totals = ProductionTotals(rows.map(\.metrics))
        VStack(spacing: 0) {
            filterBar
            totalsStrip(totals)
            table(rows)
        }
        .ipbScreenBackground()
        .searchable(text: $query, prompt: "Corte, lista, estilo, cliente…")
        .navigationTitle(isPlantManager ? "Producción · \(session.user?.plant?.displayName ?? "Sin planta")" : "Reportes de producción")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { sortMenu }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: ProductionCSV(rows: rows),
                    preview: SharePreview("Reporte de producción IPB", image: Image(systemName: "tablecells"))
                ) {
                    Label("Exportar CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(rows.isEmpty)
            }
        }
        .overlay {
            if isPlantManager && session.user?.plant == nil {
                ContentUnavailableView(
                    "Sin planta asignada", systemImage: "building.2",
                    description: Text("Pide al administrador que te asigne una planta para ver su producción."))
            }
        }
    }

    // MARK: Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if !isPlantManager {
                    FilterMenu(title: plant?.displayName ?? "Planta", symbol: "building.2", isActive: plant != nil) {
                        Picker("Planta", selection: $plant) {
                            Text("Todas").tag(Plant?.none)
                            ForEach(plants) { Text($0.displayName).tag(Optional($0)) }
                        }
                    }
                }
                FilterMenu(title: client?.displayName ?? "Cliente", symbol: "person.2", isActive: client != nil) {
                    Picker("Cliente", selection: $client) {
                        Text("Todos").tag(Client?.none)
                        ForEach(clients) { Text($0.displayName).tag(Optional($0)) }
                    }
                }
                FilterMenu(title: status?.title ?? "Estado", symbol: "scissors", isActive: status != nil) {
                    Picker("Estado", selection: $status) {
                        Text("Todos").tag(CutStatus?.none)
                        ForEach(CutStatus.allCases) { Label($0.title, systemImage: $0.symbol).tag(Optional($0)) }
                    }
                }
                Button {
                    showDateFilter = true
                } label: {
                    FilterChip(
                        title: useDateRange ? "\(Fmt.shortDate(from)) – \(Fmt.shortDate(to))" : "Fecha cliente",
                        symbol: "calendar", isActive: useDateRange)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDateFilter) {
                    Form {
                        Toggle("Filtrar por fecha cliente", isOn: $useDateRange)
                        DatePicker("Desde", selection: $from, displayedComponents: .date)
                        DatePicker("Hasta", selection: $to, in: from..., displayedComponents: .date)
                    }
                    .frame(width: 360, height: 220)
                }
                Button {
                    onlyPending.toggle()
                } label: {
                    FilterChip(title: "Con pendientes por enviar", symbol: "shippingbox", isActive: onlyPending)
                }
                .buttonStyle(.plain)
                if hasFilters {
                    Button("Limpiar", systemImage: "xmark.circle.fill") {
                        withAnimation {
                            plant = nil; client = nil; status = nil; onlyPending = false; useDateRange = false; query = ""
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    private func totalsStrip(_ t: ProductionTotals) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                TotalChip(title: "Cantidad total", value: Fmt.int(t.quantity), symbol: "number", tint: Theme.brand)
                TotalChip(title: "Producidas", value: Fmt.int(t.produced), symbol: "gearshape.2", tint: Theme.info)
                TotalChip(title: "Plancha", value: Fmt.int(t.ironing), symbol: "flame", tint: Color(hex: 0xC2410C))
                TotalChip(title: "Empaque", value: Fmt.int(t.packing), symbol: "shippingbox", tint: Color(hex: 0x6E56CF))
                TotalChip(title: "Bodega", value: Fmt.int(t.warehouse), symbol: "building.columns", tint: Color(hex: 0x0E7490))
                TotalChip(title: "Enviadas", value: Fmt.int(t.shipped), symbol: "paperplane.fill", tint: Theme.success)
                TotalChip(title: "A enviar", value: Fmt.int(t.toShip), symbol: "clock.arrow.circlepath", tint: Theme.warning)
                TotalChip(title: "Ingresos", value: Fmt.money(t.revenue, compact: true), symbol: "banknote", tint: Theme.thread)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func table(_ rows: [ProductionRow]) -> some View {
        if rows.isEmpty {
            ContentUnavailableView(
                hasFilters ? "Sin resultados" : "Aún no hay cortes en producción",
                systemImage: hasFilters ? "line.3.horizontal.decrease.circle" : "chart.bar.doc.horizontal",
                description: Text(hasFilters ? "Ajusta o limpia los filtros." : "Asigna cortes a plantas para verlos aquí.")
            )
            .frame(maxHeight: .infinity)
        } else {
            productionTable(rows)
        }
    }

    /// Custom list instead of `Table`: on iPadOS 26 `Table` lays out under the floating sidebar.
    private func productionTable(_ rows: [ProductionRow]) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(rows) { row in
                    NavigationLink(value: Route.assignment(row.id)) {
                        ProductionRowView(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Ordenar por", selection: $sortKey) {
                ForEach(SortKey.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Descendente", isOn: $sortDescending)
        } label: {
            Label("Ordenar", systemImage: "arrow.up.arrow.down")
        }
    }
}

/// Sort options for the production list.
enum SortKey: String, CaseIterable, Identifiable {
    case clientDate, code, plant, status, quantity, toShip, revenue
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clientDate: "Fecha de entrega"
        case .code: "Corte"
        case .plant: "Planta"
        case .status: "Estado"
        case .quantity: "Cantidad"
        case .toShip: "Por enviar"
        case .revenue: "Ingreso"
        }
    }

    func comparator(descending: Bool) -> [KeyPathComparator<ProductionRow>] {
        let order: SortOrder = descending ? .reverse : .forward
        switch self {
        case .clientDate: return [KeyPathComparator(\.clientDate, order: order)]
        case .code: return [KeyPathComparator(\.code, order: order)]
        case .plant: return [KeyPathComparator(\.plant, order: order)]
        case .status: return [KeyPathComparator(\.statusTitle, order: order)]
        case .quantity: return [KeyPathComparator(\.quantity, order: order)]
        case .toShip: return [KeyPathComparator(\.toShip, order: order)]
        case .revenue: return [KeyPathComparator(\.revenue, order: order)]
        }
    }
}

/// One production row; shows more metric columns when there is room.
private struct ProductionRowView: View {
    let row: ProductionRow

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.code).font(.headline)
                    Text(row.plant)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent(for: row.plant))
                }
                Text("\(row.client) · Lista \(row.list)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                CutStatusPill(status: row.status)
            }
            .frame(minWidth: 180, alignment: .leading)
            Spacer(minLength: 8)
            ViewThatFits(in: .horizontal) {
                metrics(full: true)
                metrics(full: false)
            }
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
        .contentShape(.rect)
    }

    private func metrics(full: Bool) -> some View {
        HStack(spacing: 18) {
            metric("Cantidad", Fmt.int(row.quantity))
            if full {
                metric("Cortadas", Fmt.int(row.realCut))
                metric("Producidas", Fmt.int(row.produced))
                metric("Enviadas", Fmt.int(row.shipped))
            }
            metric("Por enviar", Fmt.int(row.toShip), tint: row.toShip > 0 ? Theme.warning : Theme.success)
            metric("Entrega", row.clientDate == .distantFuture ? "—" : Fmt.shortDate(row.clientDate))
            if full { metric("Ingreso", Fmt.money(row.revenue, compact: true)) }
        }
    }

    private func metric(_ title: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(minWidth: 64, alignment: .trailing)
    }
}

// MARK: - Small pieces

private struct FilterMenu<Content: View>: View {
    var title: String
    var symbol: String
    var isActive: Bool
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            FilterChip(title: title, symbol: symbol, isActive: isActive, showsChevron: true)
        }
    }
}

struct FilterChip: View {
    var title: String
    var symbol: String
    var isActive: Bool
    var showsChevron = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title).lineLimit(1)
            if showsChevron { Image(systemName: "chevron.down").font(.caption2.weight(.bold)) }
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(isActive ? .white : .primary)
        .background(isActive ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Theme.surface), in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.stroke))
        .animation(.spring(duration: 0.25), value: isActive)
    }
}

private struct TotalChip: View {
    var title: String
    var value: String
    var symbol: String
    var tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.headline.monospacedDigit()).contentTransition(.numericText())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
    }
}

/// CSV export, generated lazily when the share sheet asks for it.
struct ProductionCSV: Transferable {
    var rows: [ProductionRow]

    var csv: String {
        let header = [
            "Corte", "Lista", "Cliente", "Estilo", "Prenda", "Planta", "Estado", "Cantidad", "Cortadas", "Producidas",
            "Plancha", "Empaque", "Bodega", "Enviadas", "Por enviar", "Ingreso", "Fecha IPB", "Fecha cliente",
        ]
        let iso = Date.ISO8601FormatStyle().year().month().day()
        func esc(_ s: String) -> String {
            s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
        }
        func date(_ d: Date) -> String { (d == .distantPast || d == .distantFuture) ? "" : d.formatted(iso) }
        let lines = rows.map { r in
            [
                r.code, r.list, r.client, r.style, r.garment, r.plant, r.status.title, "\(r.quantity)", "\(r.realCut)", "\(r.produced)",
                "\(r.ironing)", "\(r.packing)", "\(r.warehouse)", "\(r.shipped)", "\(r.toShip)", String(format: "%.2f", r.revenue),
                date(r.ipbDate), date(r.clientDate),
            ].map(esc).joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + lines).joined(separator: "\n")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { doc in
            // BOM so Excel opens accents correctly.
            Data("\u{FEFF}".utf8) + Data(doc.csv.utf8)
        }
        .suggestedFileName("IPB-produccion.csv")
    }
}

#Preview {
    let persistence = PersistenceController.preview
    return NavigationStack { ProductionReportsView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(Session(context: persistence.viewContext))
        .environment(ToastCenter())
        .environment(AppRouter())
}
