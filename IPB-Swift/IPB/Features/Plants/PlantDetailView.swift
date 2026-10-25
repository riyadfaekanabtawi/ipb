import Charts
import SwiftUI

struct PlantDetailView: View {
    @ObservedObject var plant: Plant

    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var statusFilter: CutStatus?

    var body: some View {
        let ledger = plant.ledger
        let assignments = plant.assignmentList.reversed().filter { statusFilter == nil || $0.cuttingStatus == statusFilter }

        VStack(alignment: .leading, spacing: 28) {
            hero(ledger: ledger)
            PlantCapacityChart(ledger: ledger, year: $year, years: availableYears(ledger))
                .card()

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("Asignaciones", subtitle: "\(Fmt.int(plant.assignmentList.count)) en total") {
                    Picker("Estado", selection: $statusFilter.animation(.snappy)) {
                        Text("Todas").tag(CutStatus?.none)
                        ForEach(CutStatus.allCases) { status in
                            Text(status.title).tag(Optional(status))
                        }
                    }
                    .pickerStyle(.menu)
                }
                if assignments.isEmpty {
                    ContentUnavailableView(
                        statusFilter == nil ? "Sin asignaciones" : "Nada en este estado", systemImage: "scissors",
                        description: Text("Los cortes asignados a esta planta aparecerán aquí.")
                    )
                    .frame(maxWidth: .infinity)
                    .card()
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(assignments, id: \.objectID) { assignment in
                            NavigationLink(value: Route.assignment(assignment.objectID)) {
                                PlantAssignmentRow(assignment: assignment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .catalogScroll()
        .navigationTitle(plant.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Editar", systemImage: "pencil") { editing = true }
                    .keyboardShortcut("e", modifiers: .command)
                Menu {
                    Button("Eliminar planta", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Más opciones")
            }
        }
        .sheet(isPresented: $editing) { PlantEditorSheet(plant: plant) }
        .confirmDelete(
            "¿Eliminar \(plant.displayName)?", isPresented: $confirmingDelete,
            message: "Solo se pueden eliminar plantas sin cortes asignados.", action: delete)
    }

    private func hero(ledger: CapacityLedger) -> some View {
        let now = Date.now
        let used = ledger.used(inMonthOf: now)
        return VStack(alignment: .leading, spacing: 18) {
            DetailHero(
                plant.displayName,
                subtitle: "Capacidad de \(Fmt.money(plant.maxCapacity)) por mes"
            ) {
                AvatarView(name: plant.displayName, size: 72, symbol: "building.2.fill")
            } trailing: {
                HStack(spacing: 10) {
                    HeroStat(value: Fmt.money(used, compact: true), label: "Usado este mes")
                    HeroStat(value: Fmt.money(max(0, ledger.available(inMonthOf: now)), compact: true), label: "Disponible")
                    HeroStat(value: Fmt.int(plant.openAssignmentCount), label: "Activas")
                }
            }
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ocupación de \(now.formatted(.dateTime.month(.wide)))").font(.subheadline.weight(.semibold))
                    CapacityBar(used: used, max: plant.maxCapacity, height: 14)
                }
                Text(Fmt.percent(ledger.utilization(inMonthOf: now)))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(CapacityBar.tint(for: ledger.utilization(inMonthOf: now)))
                    .contentTransition(.numericText())
                Divider().frame(height: 44)
                ManagersStack(managers: plant.plantManagers)
            }
            .card()
        }
    }

    private func availableYears(_ ledger: CapacityLedger) -> ClosedRange<Int> {
        let calendar = Calendar.current
        let current = calendar.component(.year, from: .now)
        let years = ledger.bookings.map { calendar.component(.year, from: $0.date) }
        return min(years.min() ?? current, current)...max(years.max() ?? current, current + 1)
    }

    private func delete() {
        let name = plant.displayName
        do {
            try session.service.delete(plant)
            toasts.show("Planta «\(name)» eliminada")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

/// 12-month bar chart of booked capacity against the plant's monthly maximum.
struct PlantCapacityChart: View {
    var ledger: CapacityLedger
    @Binding var year: Int
    var years: ClosedRange<Int>

    @State private var selectedMonth: Date?

    private struct MonthUsage: Identifiable {
        var month: Date
        var used: Double
        var id: Date { month }
    }

    private var months: [MonthUsage] {
        let calendar = Calendar.current
        let usage = ledger.monthlyUsage(year: year)
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1)).map {
                MonthUsage(month: $0, used: usage[month] ?? 0)
            }
        }
    }

    var body: some View {
        let data = months
        let total = data.reduce(0) { $0 + $1.used }
        let selected = selectedMonth.flatMap { date in
            data.first { Calendar.current.isDate($0.month, equalTo: date, toGranularity: .month) }
        }

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capacidad por mes").font(.title3.weight(.bold))
                    Text("Asignado en \(String(year)): \(Fmt.money(total, compact: true))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                YearStepper(year: $year, range: years)
            }

            Chart {
                ForEach(data) { item in
                    BarMark(x: .value("Mes", item.month, unit: .month), y: .value("Usado", item.used))
                        .foregroundStyle(CapacityBar.tint(for: ratio(item.used)).gradient)
                        .cornerRadius(6)
                        .opacity(selected == nil || selected?.id == item.id ? 1 : 0.45)
                }
                if ledger.maxCapacity > 0 {
                    RuleMark(y: .value("Capacidad máxima", ledger.maxCapacity))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Theme.danger)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Máx. \(Fmt.money(ledger.maxCapacity, compact: true))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.danger)
                        }
                }
                if let selected {
                    RuleMark(x: .value("Mes", selected.month, unit: .month))
                        .foregroundStyle(Theme.brand.opacity(0.15))
                        .zIndex(-1)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selected.month.formatted(.dateTime.month(.wide).year())).font(.caption.weight(.semibold))
                                Text("Usado \(Fmt.money(selected.used))").font(.caption)
                                Text("Disponible \(Fmt.money(max(0, ledger.maxCapacity - selected.used)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(.regularMaterial, in: .rect(cornerRadius: 10, style: .continuous))
                        }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartYScale(domain: 0...max(ledger.maxCapacity * 1.15, (data.map(\.used).max() ?? 0) * 1.1, 1))
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(Fmt.money(amount, compact: true)) }
                    }
                }
            }
            .frame(height: 280)
            .animation(.spring(duration: 0.45), value: year)
            .accessibilityLabel("Gráfica de capacidad usada por mes en \(String(year))")
        }
    }

    private func ratio(_ used: Double) -> Double { ledger.maxCapacity > 0 ? used / ledger.maxCapacity : 0 }
}

/// Compact ‹ 2026 › year switcher.
struct YearStepper: View {
    @Binding var year: Int
    var range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.snappy) { year -= 1 }
            } label: {
                Image(systemName: "chevron.left").frame(width: 32, height: 32)
            }
            .disabled(year <= range.lowerBound)
            .accessibilityLabel("Año anterior")

            Text(String(year))
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText(value: Double(year)))
                .frame(minWidth: 52)

            Button {
                withAnimation(.snappy) { year += 1 }
            } label: {
                Image(systemName: "chevron.right").frame(width: 32, height: 32)
            }
            .disabled(year >= range.upperBound)
            .accessibilityLabel("Año siguiente")
        }
        .buttonStyle(.borderless)
        .padding(4)
        .background(Theme.brand.opacity(0.08), in: .capsule)
    }
}

private struct PlantAssignmentRow: View {
    @ObservedObject var assignment: Assignment

    var body: some View {
        let metrics = assignment.metrics
        let status = assignment.cuttingStatus
        CatalogRowCard {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
                .frame(width: 40, height: 40)
                .background(status.tint.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.title).font(.headline)
                Text(assignment.order?.clientName ?? "Sin cliente").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(minWidth: 160, alignment: .leading)
            Spacer(minLength: 8)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 22) {
                    stat(Fmt.int(Int(assignment.quantity)), "prendas")
                    stat(Fmt.shortDate(assignment.scheduledDate), "fecha")
                    stat(Fmt.int(metrics.toShip), "por enviar")
                    Pill(text: status.title, symbol: nil, tint: status.tint)
                }
                HStack(spacing: 16) {
                    stat(Fmt.int(metrics.toShip), "por enviar")
                    Pill(text: status.title, symbol: nil, tint: status.tint)
                }
                Pill(text: status.title, symbol: nil, tint: status.tint)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview("Detalle de planta") {
    NavigationStack { PlantDetailView(plant: CatalogPreviewData.first(Plant.self)) }
        .catalogPreviewEnvironment()
}
