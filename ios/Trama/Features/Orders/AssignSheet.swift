import CoreData
import SwiftUI

/// Assign part of a cut order to a plant for a month. Every plant shows its capacity for the
/// chosen month with a live preview of what this assignment would add, so the planner sees the
/// fit before confirming (the legacy app only told you afterwards that capacity was exceeded).
struct AssignSheet: View {
    @ObservedObject var order: CutOrder

    @Environment(\.dismiss) private var dismiss
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts
    @FetchRequest(sortDescriptors: [SortDescriptor(\Plant.name)]) private var plants: FetchedResults<Plant>

    @State private var quantity = 0
    @State private var date = Date()
    @State private var selectedPlant: Plant?

    private var value: Double { Double(quantity) * order.unitPrice }

    private var validation: Result<Double, AssignmentError>? {
        guard let plant = selectedPlant else { return nil }
        return AssignmentRules.validate(
            quantity: quantity, unitPrice: order.unitPrice, remaining: order.remainingQuantity,
            date: date, ledger: plant.ledger)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        controls.frame(width: 380)
                        plantPicker
                    }
                    VStack(spacing: 20) {
                        controls
                        plantPicker
                    }
                }
                .padding(24)
            }
            .tramaScreenBackground()
            .safeAreaInset(edge: .bottom) { summaryBar }
            .navigationTitle("Asignar \(order.displayCode)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            quantity = order.remainingQuantity
            selectedPlant = bestFit()
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    "Cantidad", subtitle: "\(order.remainingQuantity) prendas pendientes de \(Int(order.quantity))")
                HStack {
                    TextField("0", value: $quantity, format: .number)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                        .monospacedDigit()
                    Text("prendas").foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(get: { Double(quantity) }, set: { quantity = Int($0.rounded()) }),
                    in: 0...Double(max(order.remainingQuantity, 1)), step: 1)
                HStack {
                    ForEach([0.25, 0.5, 1.0], id: \.self) { fraction in
                        Button(fraction == 1 ? String(localized: "Todo") : Fmt.percent(fraction)) {
                            withAnimation { quantity = Int((Double(order.remainingQuantity) * fraction).rounded()) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                InfoRow(label: "Valor de la asignación", value: Fmt.money(value), symbol: "banknote")
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Mes de producción", subtitle: "La capacidad de cada planta es mensual")
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Theme.brand)
            }
            .card()

            let distribution = order.style?.plantDistribution ?? []
            if !distribution.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Este estilo ya se produce en")
                    FlowRow(spacing: 8) {
                        ForEach(distribution, id: \.plant.objectID) { item in
                            Pill(
                                text: item.plant.displayName + " · " + Fmt.int(item.count), symbol: "building.2",
                                tint: Theme.accent(for: item.plant.displayName))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
        }
    }

    private var plantPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Plantas", subtitle: "Capacidad de \(date.formatted(.dateTime.month(.wide).year()))")
            if plants.isEmpty {
                ContentUnavailableView(
                    "No hay plantas", systemImage: "building.2", description: Text("Crea una planta en Catálogos → Plantas."))
            }
            ForEach(plants) { plant in
                PlantCapacityOption(plant: plant, date: date, preview: value, isSelected: selectedPlant == plant) {
                    withAnimation(.spring(duration: 0.3)) { selectedPlant = plant }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Summary

    private var summaryBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                if let plant = selectedPlant {
                    Text("\(quantity) prendas → \(plant.displayName)").font(.headline)
                    if case .failure(let error) = validation {
                        Text(error.localizedDescription).font(.caption).foregroundStyle(Theme.danger)
                    } else {
                        Text("\(Fmt.money(value)) en \(date.formatted(.dateTime.month(.wide)))").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Elige una planta").font(.headline)
                }
            }
            Spacer()
            Button(action: assign) {
                Label("Asignar", systemImage: "checkmark")
            }
            .buttonStyle(.tramaPrimary)
            .frame(width: 200)
            .disabled(!isValid)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var isValid: Bool {
        if case .success = validation { return true }
        return false
    }

    /// Default to the plant with the most room this month that fits the whole quantity.
    private func bestFit() -> Plant? {
        plants
            .filter { $0.ledger.available(inMonthOf: date) >= value }
            .max { $0.ledger.available(inMonthOf: date) < $1.ledger.available(inMonthOf: date) }
            ?? plants.first
    }

    private func assign() {
        guard let plant = selectedPlant else { return }
        do {
            try session.service.assign(order: order, to: plant, quantity: quantity, date: date)
            toasts.show("Asignaste \(quantity) prendas a \(plant.displayName)")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

private struct PlantCapacityOption: View {
    @ObservedObject var plant: Plant
    var date: Date
    var preview: Double
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        let ledger = plant.ledger
        let used = ledger.used(inMonthOf: date)
        let available = ledger.available(inMonthOf: date)
        let fits = preview <= available + 0.000_1

        Button(action: select) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    AvatarView(name: plant.displayName, size: 40, symbol: "building.2.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plant.displayName).font(.headline)
                        Text("Máx. \(Fmt.money(plant.maxCapacity))/mes").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Pill(
                        text: fits ? "Cabe" : "Excede", symbol: fits ? "checkmark" : "exclamationmark.triangle",
                        tint: fits ? Theme.success : Theme.danger)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Theme.brand : Color.secondary.opacity(0.4))
                        .symbolEffect(.bounce, value: isSelected)
                }
                CapacityBar(used: used, max: plant.maxCapacity, preview: isSelected ? preview : 0, height: 14)
                HStack {
                    Text("Usado \(Fmt.money(used, compact: true))")
                    Spacer()
                    Text("Disponible \(Fmt.money(max(0, available), compact: true))")
                        .foregroundStyle(available > 0 ? Theme.success : Theme.danger)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Theme.surface, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Theme.brand : Theme.stroke, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
