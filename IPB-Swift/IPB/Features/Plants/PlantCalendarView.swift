import CoreData
import SwiftUI

/// Month calendar of production (assignment dates) and client deliveries, with each plant's
/// capacity for the month (legacy CalendarViewController with one FSCalendar per plant).
struct PlantCalendarView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\Plant.name)]) private var plants: FetchedResults<Plant>
    @FetchRequest(sortDescriptors: []) private var assignments: FetchedResults<Assignment>
    @FetchRequest(sortDescriptors: []) private var orders: FetchedResults<CutOrder>

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var plantFilter: Plant?
    @State private var selectedDay: Date?

    private let calendar = Calendar.current

    struct Event: Identifiable {
        enum Kind { case production, delivery }
        let id: String
        let kind: Kind
        let date: Date
        let title: String
        let subtitle: String
        let tint: Color
        let route: Route
    }

    private var events: [Event] {
        let production = assignments.compactMap { a -> Event? in
            guard let date = a.scheduledDate, plantFilter == nil || a.plant == plantFilter else { return nil }
            return Event(
                id: "p-\(a.objectID)", kind: .production, date: date, title: a.title,
                subtitle: "\(a.plantName) · \(Fmt.int(Int(a.quantity))) prendas", tint: Theme.accent(for: a.plantName),
                route: .assignment(a.objectID))
        }
        let deliveries = orders.compactMap { o -> Event? in
            guard let date = o.clientDate else { return nil }
            if let plantFilter, !o.assignmentList.contains(where: { $0.plant == plantFilter }) { return nil }
            return Event(
                id: "d-\(o.objectID)", kind: .delivery, date: date, title: o.displayCode,
                subtitle: "Entrega a \(o.clientName)", tint: Theme.danger, route: .order(o.objectID))
        }
        return (production + deliveries).filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    var body: some View {
        let events = self.events
        let byDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                capacityStrip
                monthGrid(byDay)
                legend
            }
            .padding(24)
        }
        .ipbScreenBackground()
        .navigationTitle("Calendario de plantas")
        .inspector(isPresented: Binding(get: { selectedDay != nil }, set: { if !$0 { selectedDay = nil } })) {
            if let day = selectedDay {
                DayInspector(day: day, events: byDay[day] ?? [])
                    .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                shift(-1)
            } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.semibold))
            }
            .accessibilityLabel("Mes anterior")
            .keyboardShortcut(.leftArrow, modifiers: .command)
            Text(month.formatted(.dateTime.month(.wide).year()).capitalizedFirst)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .frame(minWidth: 260, alignment: .leading)
            Button {
                shift(1)
            } label: {
                Image(systemName: "chevron.right").font(.title3.weight(.semibold))
            }
            .accessibilityLabel("Mes siguiente")
            .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Hoy") {
                withAnimation { month = calendar.dateInterval(of: .month, for: .now)?.start ?? .now }
            }
            .buttonStyle(.bordered)
            Spacer()
            Picker("Planta", selection: $plantFilter) {
                Text("Todas las plantas").tag(Plant?.none)
                ForEach(plants) { Text($0.displayName).tag(Optional($0)) }
            }
            .pickerStyle(.menu)
        }
    }

    private var capacityStrip: some View {
        let shown = plantFilter.map { [$0] } ?? Array(plants)
        return LazyVGrid(columns: AdaptiveGrid.adaptive(min: 260, spacing: 14), spacing: 14) {
            ForEach(shown) { plant in
                let ledger = plant.ledger
                let used = ledger.used(inMonthOf: month)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(plant.displayName).font(.headline)
                        Spacer()
                        Text(Fmt.percent(ledger.utilization(inMonthOf: month)))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(CapacityBar.tint(for: ledger.utilization(inMonthOf: month)))
                    }
                    CapacityBar(used: used, max: plant.maxCapacity)
                    HStack {
                        Text("Usada \(Fmt.money(used, compact: true))")
                        Spacer()
                        Text("Disponible \(Fmt.money(max(0, plant.maxCapacity - used), compact: true))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .card(padding: 16)
            }
        }
    }

    private func monthGrid(_ byDay: [Date: [Event]]) -> some View {
        let days = gridDays()
        let symbols = weekdaySymbols()
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    if let day {
                        DayCell(day: day, events: byDay[day] ?? [], isToday: calendar.isDateInToday(day), isSelected: selectedDay == day)
                            .onTapGesture { withAnimation(.snappy) { selectedDay = selectedDay == day ? nil : day } }
                    } else {
                        Color.clear.frame(height: 110)
                    }
                }
            }
        }
        .card(padding: 16)
        .gesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                if value.translation.width < -60 { shift(1) } else if value.translation.width > 60 { shift(-1) }
            })
    }

    private var legend: some View {
        HStack(spacing: 20) {
            Label("Inicio de producción (color por planta)", systemImage: "scissors")
            Label("Entrega al cliente", systemImage: "flag.fill").foregroundStyle(Theme.danger)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: Calendar math

    private func shift(_ months: Int) {
        withAnimation(.snappy) {
            month = calendar.date(byAdding: .month, value: months, to: month) ?? month
            selectedDay = nil
        }
    }

    /// Leading blanks + every day of the month.
    private func gridDays() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

private struct DayCell: View {
    var day: Date
    var events: [PlantCalendarView.Event]
    var isToday: Bool
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.formatted(.dateTime.day()))
                .font(.subheadline.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 28, height: 28)
                .background(isToday ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(.clear), in: .circle)
            ForEach(events.prefix(3)) { event in
                HStack(spacing: 4) {
                    Image(systemName: event.kind == .delivery ? "flag.fill" : "scissors").font(.system(size: 9, weight: .bold))
                    Text(event.title).lineLimit(1)
                }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(event.tint)
                .background(event.tint.opacity(0.14), in: .rect(cornerRadius: 6, style: .continuous))
            }
            if events.count > 3 {
                Text("+\(events.count - 3) más").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(isSelected ? Theme.brand.opacity(0.12) : Theme.surfaceRaised, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(
                isSelected ? Theme.brand : Theme.stroke, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(events.count) eventos")
        .accessibilityAddTraits(.isButton)
    }
}

private struct DayInspector: View {
    var day: Date
    var events: [PlantCalendarView.Event]

    var body: some View {
        List {
            Section {
                if events.isEmpty {
                    Text("Sin producción ni entregas este día.").foregroundStyle(.secondary)
                }
                ForEach(events) { event in
                    NavigationLink(value: event.route) {
                        HStack(spacing: 12) {
                            Image(systemName: event.kind == .delivery ? "flag.fill" : "scissors")
                                .foregroundStyle(event.tint)
                                .frame(width: 32, height: 32)
                                .background(event.tint.opacity(0.14), in: .rect(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.headline)
                                Text(event.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalizedFirst)
                    .font(.title3.bold())
                    .textCase(nil)
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    let persistence = PersistenceController.preview
    return NavigationStack { PlantCalendarView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(Session(context: persistence.viewContext))
        .environment(ToastCenter())
        .environment(AppRouter())
}
