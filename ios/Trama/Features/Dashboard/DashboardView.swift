import Charts
import CoreData
import SwiftUI

/// Admin landing page: live KPIs, plant capacity, booked revenue, cutting pipeline and
/// the lists that need attention today. Everything derives from Core Data, so it is always current.
struct DashboardView: View {
    @Environment(Session.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(ConnectivityMonitor.self) private var connectivity
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]) private var plants: FetchedResults<Plant>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "clientDate", ascending: true)]) private var orders: FetchedResults<CutOrder>
    @FetchRequest(sortDescriptors: []) private var assignments: FetchedResults<Assignment>
    @FetchRequest(fetchRequest: DashboardView.recentReportsRequest) private var recentReports: FetchedResults<ProductionReport>

    @AppStorage("settings.urgencyWindowDays") private var urgencyWindow = 7
    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var updatedAt = Date.now

    private static var recentReportsRequest: NSFetchRequest<ProductionReport> {
        let request = NSFetchRequest<ProductionReport>(entityName: "ProductionReport")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 8
        return request
    }

    var body: some View {
        // Computed once per render; every card reads from this snapshot.
        let snapshot = DashboardSnapshot(
            plants: Array(plants), orders: Array(orders), assignments: Array(assignments),
            month: month, urgencyWindow: urgencyWindow)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DashboardHero(
                    name: session.user?.firstName, isOnline: connectivity.isOnline, updatedAt: updatedAt,
                    urgentCount: snapshot.urgent.count, unassigned: snapshot.unassignedGarments)

                kpis(snapshot)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        CapacityChartCard(points: snapshot.capacity, month: $month)
                            .frame(maxWidth: .infinity)
                        PipelineChartCard(slices: snapshot.pipeline) { router.open(.board) }
                            .frame(width: 340)
                    }
                    .frame(minWidth: 900)
                    VStack(spacing: 18) {
                        CapacityChartCard(points: snapshot.capacity, month: $month)
                        PipelineChartCard(slices: snapshot.pipeline) { router.open(.board) }
                    }
                }

                RevenueYearChartCard(points: snapshot.yearly, plantNames: snapshot.plantNames, month: $month)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        urgentList(snapshot)
                        pendingList(snapshot)
                    }
                    .frame(minWidth: 900)
                    VStack(spacing: 18) {
                        urgentList(snapshot)
                        pendingList(snapshot)
                    }
                }

                ReportsFeedCard(reports: Array(recentReports.prefix(8))) { report in
                    if let id = report.assignment?.objectID {
                        router.open(.production, pushing: Route.assignment(id))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1_400)
            .frame(maxWidth: .infinity)
        }
        .tramaScreenBackground()
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)) { _ in
            updatedAt = .now
        }
    }

    // MARK: KPIs

    private func kpis(_ s: DashboardSnapshot) -> some View {
        LazyVGrid(columns: AdaptiveGrid.adaptive(min: 180, spacing: 16), spacing: 16) {
            KPITile(
                title: "Ingresos en producción", value: Fmt.money(s.revenue, compact: true), symbol: "banknote.fill",
                tint: Theme.brand, footnote: "\(Fmt.int(s.assignmentCount)) asignaciones"
            ) { router.open(.production) }
            KPITile(
                title: "Prendas por asignar", value: Fmt.int(s.unassignedGarments), symbol: "scissors",
                tint: Theme.thread, footnote: "\(Fmt.int(s.pendingOrders.count)) cortes pendientes"
            ) { router.open(.orders) }
            KPITile(
                title: "En producción", value: Fmt.int(s.inProduction), symbol: "gearshape.2.fill",
                tint: Theme.info, footnote: "Cortes sin terminar"
            ) { router.open(.production) }
            KPITile(
                title: "Envíos urgentes", value: Fmt.int(s.urgent.count), symbol: "exclamationmark.triangle.fill",
                tint: s.urgent.isEmpty ? Theme.success : Theme.danger, footnote: "Próximos \(urgencyWindow) días"
            ) { router.open(.shipments) }
            KPITile(
                title: "Por enviar", value: Fmt.int(s.toShip), symbol: "shippingbox.fill",
                tint: Theme.success, footnote: "Prendas"
            ) { router.open(.shipments) }
        }
        .animation(.spring(duration: 0.5), value: s.revenue)
        .animation(.spring(duration: 0.5), value: s.toShip)
    }

    // MARK: Lists

    private func urgentList(_ s: DashboardSnapshot) -> some View {
        ChartCard("Envíos urgentes", subtitle: "Por fecha de cliente") {
            Button("Ver todos") { router.open(.shipments) }.font(.subheadline.weight(.semibold))
        } content: {
            if s.urgent.isEmpty {
                CardEmptyState(
                    title: "Sin envíos urgentes", symbol: "checkmark.seal",
                    message: "Todo va a tiempo en los próximos \(urgencyWindow) días.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(s.urgent.prefix(5).enumerated()), id: \.element.assignment.objectID) { index, row in
                        if index > 0 { Divider().padding(.leading, 56) }
                        Button {
                            router.open(.production, pushing: Route.assignment(row.assignment.objectID))
                        } label: {
                            UrgentRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pendingList(_ s: DashboardSnapshot) -> some View {
        ChartCard("Cortes por asignar", subtitle: "Más próximos a entregar") {
            Button("Ver todos") { router.open(.orders) }.font(.subheadline.weight(.semibold))
        } content: {
            if s.pendingOrders.isEmpty {
                CardEmptyState(title: "Todo asignado", symbol: "tray", message: "No hay prendas pendientes de asignar a planta.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(s.pendingOrders.prefix(5).enumerated()), id: \.element.objectID) { index, order in
                        if index > 0 { Divider().padding(.leading, 56) }
                        Button {
                            router.open(.orders, pushing: Route.order(order.objectID))
                        } label: {
                            PendingOrderRow(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Snapshot

/// Everything the dashboard shows, derived in one pass from the fetched objects.
struct DashboardSnapshot {
    struct UrgentItem {
        var assignment: Assignment
        var toShip: Int
        var daysLeft: Int?
    }

    struct CapacityPoint: Identifiable {
        var id: String { plant }
        var plant: String
        var used: Double
        var max: Double
        var ratio: Double { max > 0 ? used / max : 0 }
    }

    struct MonthPoint: Identifiable {
        var id: String { "\(plant)-\(month.timeIntervalSince1970)" }
        var plant: String
        var month: Date
        var amount: Double
    }

    struct PipelineSlice: Identifiable {
        var id: CutStatus { status }
        var status: CutStatus
        var count: Int
    }

    var revenue: Double = 0
    var assignmentCount = 0
    var inProduction = 0
    var toShip = 0
    var unassignedGarments = 0
    var urgent: [UrgentItem] = []
    var pendingOrders: [CutOrder] = []
    var pipeline: [PipelineSlice] = []
    var capacity: [CapacityPoint] = []
    var yearly: [MonthPoint] = []
    var plantNames: [String] = []

    init(plants: [Plant], orders: [CutOrder], assignments: [Assignment], month: Date, urgencyWindow: Int, now: Date = .now) {
        let calendar = Calendar.current
        var statusCounts: [CutStatus: Int] = [:]
        assignmentCount = assignments.count
        for assignment in assignments {
            let metrics = assignment.metrics
            revenue += metrics.revenue
            toShip += metrics.toShip
            if !metrics.isComplete { inProduction += 1 }
            statusCounts[assignment.cuttingStatus, default: 0] += 1
            let clientDate = assignment.order?.clientDate
            if UrgencyPolicy.isUrgent(toShip: metrics.toShip, clientDate: clientDate, now: now, windowDays: urgencyWindow) {
                urgent.append(
                    UrgentItem(
                        assignment: assignment, toShip: metrics.toShip, daysLeft: UrgencyPolicy.daysLeft(until: clientDate, now: now)))
            }
        }
        urgent.sort { ($0.daysLeft ?? .max) < ($1.daysLeft ?? .max) }
        pipeline = CutStatus.allCases.map { PipelineSlice(status: $0, count: statusCounts[$0] ?? 0) }

        // Orders arrive sorted by client date; undated ones go last.
        let pending = orders.filter { $0.remainingQuantity > 0 }
        pendingOrders = pending.filter { $0.clientDate != nil } + pending.filter { $0.clientDate == nil }
        unassignedGarments = pending.reduce(0) { $0 + $1.remainingQuantity }

        let year = calendar.component(.year, from: month)
        for plant in plants {
            let name = plant.displayName
            let ledger = plant.ledger
            plantNames.append(name)
            capacity.append(CapacityPoint(plant: name, used: ledger.used(inMonthOf: month), max: plant.maxCapacity))
            for (m, amount) in ledger.monthlyUsage(year: year).sorted(by: { $0.key < $1.key }) {
                if let date = calendar.date(from: DateComponents(year: year, month: m, day: 1)) {
                    yearly.append(MonthPoint(plant: name, month: date, amount: amount))
                }
            }
        }
    }
}

// MARK: - Hero

private struct DashboardHero: View {
    var name: String?
    var isOnline: Bool
    var updatedAt: Date
    var urgentCount: Int
    var unassigned: Int

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let salute =
            switch hour {
            case 5..<12: "Buenos días"
            case 12..<19: "Buenas tardes"
            default: "Buenas noches"
            }
        guard let name, !name.isEmpty else { return salute }
        return "\(salute), \(name)"
    }

    private var summary: String {
        var parts: [String] = []
        parts.append(urgentCount == 0 ? "Sin envíos urgentes" : "\(urgentCount) \(urgentCount == 1 ? "envío urgente" : "envíos urgentes")")
        parts.append(unassigned == 0 ? "todo asignado" : "\(Fmt.int(unassigned)) prendas por asignar")
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LoomBackdrop()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label(isOnline ? "En línea" : "Sin conexión · modo local", systemImage: isOnline ? "wifi" : "wifi.slash")
                        .heroCapsule()
                    Spacer()
                    Label(
                        "Actualizado \(updatedAt.formatted(date: .omitted, time: .shortened))", systemImage: "arrow.triangle.2.circlepath"
                    )
                    .heroCapsule()
                    .contentTransition(.numericText())
                    .animation(.smooth, value: updatedAt)
                }
                Spacer(minLength: 12)
                Text(greeting)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(MonthLabel.fullDay(.now))
                    .font(.title3.weight(.medium))
                    .opacity(0.85)
                Text(summary)
                    .font(.callout)
                    .opacity(0.75)
            }
            .foregroundStyle(.white)
            .padding(28)
        }
        .frame(height: 230)
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.brandDeep.opacity(0.25), radius: 24, y: 12)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func heroCapsule() -> some View {
        font(.caption.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.white.opacity(0.16), in: .capsule)
    }
}

// MARK: - Charts

private struct CapacityChartCard: View {
    var points: [DashboardSnapshot.CapacityPoint]
    @Binding var month: Date

    private var totalUsed: Double { points.reduce(0) { $0 + $1.used } }
    private var totalMax: Double { points.reduce(0) { $0 + $1.max } }

    var body: some View {
        ChartCard(
            "Capacidad de plantas",
            subtitle: totalMax > 0
                ? "\(Fmt.money(totalUsed, compact: true)) de \(Fmt.money(totalMax, compact: true)) · \(Fmt.percent(totalUsed / totalMax))"
                : "Usado vs. capacidad mensual"
        ) {
            MonthStepper(month: $month)
        } content: {
            if points.isEmpty {
                CardEmptyState(title: "Sin plantas", symbol: "building.2", message: "Da de alta plantas para ver su capacidad.")
            } else {
                Chart(points) { point in
                    BarMark(
                        xStart: .value("Inicio", 0), xEnd: .value("Capacidad", point.max),
                        y: .value("Planta", point.plant), height: 26
                    )
                    .foregroundStyle(Color.primary.opacity(0.07))
                    .clipShape(.capsule)

                    BarMark(
                        xStart: .value("Inicio", 0), xEnd: .value("Usado", min(point.used, max(point.max, point.used))),
                        y: .value("Planta", point.plant), height: 26
                    )
                    .foregroundStyle(CapacityBar.tint(for: point.ratio).gradient)
                    .clipShape(.capsule)
                    .annotation(position: .overlay, alignment: .trailing) {
                        if point.used > 0 {
                            Text(Fmt.percent(point.ratio))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.trailing, 6)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel { if let v = value.as(Double.self) { Text(Fmt.money(v, compact: true)) } }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(.subheadline.weight(.medium)) }
                }
                .frame(height: CGFloat(max(points.count, 2)) * 48 + 30)
                .animation(.spring(duration: 0.5), value: month)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    points.map { "\($0.plant): \(Fmt.percent($0.ratio)) usado" }.joined(separator: ", "))
            }
        }
    }
}

private struct PipelineChartCard: View {
    var slices: [DashboardSnapshot.PipelineSlice]
    var onOpen: () -> Void

    private var total: Int { slices.reduce(0) { $0 + $1.count } }

    var body: some View {
        ChartCard("Mesa de corte", subtitle: "Asignaciones por estado") {
            Button("Tablero", systemImage: "arrow.up.right", action: onOpen)
                .labelStyle(TrailingIconLabelStyle())
                .font(.subheadline.weight(.semibold))
        } content: {
            if total == 0 {
                CardEmptyState(title: "Sin asignaciones", symbol: "scissors", message: "Asigna cortes a una planta para verlos aquí.")
            } else {
                VStack(spacing: 18) {
                    Chart(slices) { slice in
                        SectorMark(
                            angle: .value("Asignaciones", slice.count), innerRadius: .ratio(0.64), angularInset: 2.5
                        )
                        .cornerRadius(6)
                        .foregroundStyle(slice.status.tint.gradient)
                    }
                    .chartBackground { proxy in
                        GeometryReader { geo in
                            if let frame = proxy.plotFrame {
                                let rect = geo[frame]
                                VStack(spacing: 0) {
                                    Text(Fmt.int(total))
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .contentTransition(.numericText())
                                    Text("cortes").font(.caption).foregroundStyle(.secondary)
                                }
                                .position(x: rect.midX, y: rect.midY)
                            }
                        }
                    }
                    .frame(height: 190)
                    .onTapGesture(perform: onOpen)

                    VStack(spacing: 10) {
                        ForEach(slices) { slice in
                            LegendRow(color: slice.status.tint, title: slice.status.title, value: Fmt.int(slice.count))
                        }
                    }
                }
                .animation(.spring(duration: 0.5), value: total)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Abre el tablero de corte")
            }
        }
    }
}

private struct RevenueYearChartCard: View {
    var points: [DashboardSnapshot.MonthPoint]
    var plantNames: [String]
    @Binding var month: Date
    @State private var selection: Date?

    private var year: Int { Calendar.current.component(.year, from: month) }
    private var total: Double { points.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ChartCard("Ingresos agendados \(String(year))", subtitle: "\(Fmt.money(total, compact: true)) por mes de producción, por planta") {
            if !plantNames.isEmpty {
                HStack(spacing: 12) {
                    ForEach(plantNames.prefix(4), id: \.self) { name in
                        HStack(spacing: 5) {
                            Circle().fill(Theme.accent(for: name)).frame(width: 8, height: 8)
                            Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        } content: {
            if total == 0 {
                CardEmptyState(
                    title: "Sin ingresos agendados en \(String(year))", symbol: "chart.bar",
                    message: "Las asignaciones a planta aparecerán aquí por mes.")
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Mes", point.month, unit: .month),
                        y: .value("Ingresos", point.amount)
                    )
                    .foregroundStyle(by: .value("Planta", point.plant))
                    .cornerRadius(4)
                    .opacity(Calendar.current.isDate(point.month, equalTo: month, toGranularity: .month) ? 1 : 0.55)
                }
                .chartForegroundStyleScale(domain: plantNames, range: plantNames.map { Theme.accent(for: $0) })
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) { Text(MonthLabel.short(date).capitalizedFirst) }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel { if let v = value.as(Double.self) { Text(Fmt.money(v, compact: true)) } }
                    }
                }
                .chartXSelection(value: $selection)
                .onChange(of: selection) { _, new in
                    // Tapping a month drives the capacity chart above.
                    guard let new else { return }
                    let target = Calendar.current.startOfMonth(for: new)
                    if target != month {
                        withAnimation(.spring(duration: 0.4)) { month = target }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .frame(height: 240)
                .animation(.spring(duration: 0.5), value: month)
                .accessibilityLabel("Ingresos agendados por mes en \(String(year)): \(Fmt.money(total))")
            }
        }
    }
}

// MARK: - Rows

private struct UrgentRow: View {
    var row: DashboardSnapshot.UrgentItem

    private var tint: Color {
        guard let days = row.daysLeft else { return .secondary }
        return days < 0 ? Theme.danger : days <= 2 ? Theme.warning : Theme.info
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: (row.daysLeft ?? 0) < 0 ? "exclamationmark.octagon.fill" : "clock.badge.exclamationmark.fill")
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(row.assignment.title) · \(row.assignment.order?.clientName ?? "Sin cliente")")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(row.assignment.plantName) · \(Fmt.int(row.toShip)) por enviar")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Pill(text: Fmt.relativeDays(row.daysLeft), tint: tint)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct PendingOrderRow: View {
    var order: CutOrder

    var body: some View {
        let remaining = order.remainingQuantity
        let progress = order.quantity > 0 ? Double(order.assignedQuantity) / Double(order.quantity) : 0
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: progress, tint: order.assignmentState.tint, lineWidth: 5)
                Image(systemName: "scissors").font(.caption.weight(.bold)).foregroundStyle(order.assignmentState.tint)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(order.displayCode) · \(order.list ?? "—")").font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(order.clientName) · \(order.styleName)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.int(remaining)).font(.subheadline.weight(.bold)).monospacedDigit()
                Text("Cliente \(Fmt.shortDate(order.clientDate))").font(.caption).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Corte \(order.displayCode), \(order.clientName), \(Fmt.int(remaining)) prendas por asignar")
    }
}

private struct ReportsFeedCard: View {
    var reports: [ProductionReport]
    var onOpen: (ProductionReport) -> Void

    var body: some View {
        ChartCard("Actividad reciente", subtitle: "Últimos reportes de producción") {
            EmptyView()
        } content: {
            if reports.isEmpty {
                CardEmptyState(
                    title: "Sin reportes todavía", symbol: "doc.text", message: "Los reportes de planta, corte y envío aparecerán aquí.")
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 380, spacing: 14), spacing: 4) {
                    ForEach(reports, id: \.objectID) { report in
                        Button {
                            onOpen(report)
                        } label: {
                            ReportFeedRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ReportFeedRow: View {
    var report: ProductionReport

    var body: some View {
        let kind = report.kind
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(kind.tint)
                .frame(width: 36, height: 36)
                .background(kind.tint.opacity(0.14), in: .rect(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(kind.shortTitle).font(.caption.weight(.bold)).foregroundStyle(kind.tint)
                    Text("\(report.assignment?.title ?? "Corte") · \(report.assignment?.plantName ?? "")")
                        .font(.caption.weight(.semibold)).lineLimit(1)
                }
                Text(report.summary).font(.subheadline).lineLimit(1)
                Text(
                    "\(report.authorName ?? "Sin autor") · \((report.createdAt ?? .now).formatted(.relative(presentation: .named).locale(.esMX)))"
                )
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.surfaceRaised, in: .rect(cornerRadius: Theme.smallRadius, style: .continuous))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Dashboard") {
    let persistence = PersistenceController.preview
    let session = Session(context: persistence.viewContext)
    if let admin = Session.findUser(email: "admin@demo.local", in: persistence.viewContext) { session.adopt(admin) }
    return NavigationStack { DashboardView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(session)
        .environment(ToastCenter())
        .environment(AppRouter())
        .environment(ConnectivityMonitor())
}
