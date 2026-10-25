import CoreData
import SwiftUI

struct PlantsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Plant.name, ascending: true)])
    private var plants: FetchedResults<Plant>

    @State private var search = ""
    @State private var editor: PlantEditorTarget?
    @State private var pendingDelete: Plant?

    private var filtered: [Plant] {
        plants.filter { plant in
            CatalogSearch.matches(search, [plant.name] + plant.plantManagers.map(\.fullName))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !plants.isEmpty { summary }
            if plants.isEmpty {
                ContentUnavailableView {
                    Label("Sin plantas", systemImage: "building.2")
                } description: {
                    Text("Agrega tus plantas con su capacidad mensual para empezar a asignar cortes.")
                } actions: {
                    Button("Nueva planta", systemImage: "plus") { editor = .new }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 60)
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 330), spacing: 18) {
                    ForEach(filtered, id: \.objectID) { plant in
                        NavigationLink(value: Route.plant(plant.objectID)) {
                            PlantCard(plant: plant)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Editar", systemImage: "pencil") { editor = .edit(plant) }
                            Button("Eliminar", systemImage: "trash", role: .destructive) { pendingDelete = plant }
                        }
                    }
                }
                .animation(.spring(duration: 0.35), value: filtered.map(\.objectID))
            }
        }
        .catalogScroll()
        .navigationTitle("Plantas")
        .searchable(text: $search, prompt: "Buscar planta o gerente")
        .toolbar {
            AddToolbarButton(title: "Nueva planta") { editor = .new }
        }
        .sheet(item: $editor) { target in
            PlantEditorSheet(plant: target.plant)
        }
        .confirmDelete(
            "¿Eliminar \(pendingDelete?.displayName ?? String(localized: "planta"))?", item: $pendingDelete,
            message: "Solo se pueden eliminar plantas sin cortes asignados."
        ) { plant in
            delete(plant)
        }
    }

    private var summary: some View {
        let now = Date.now
        let capacity = plants.reduce(0) { $0 + $1.maxCapacity }
        let used = plants.reduce(0) { $0 + $1.ledger.used(inMonthOf: now) }
        let active = plants.reduce(0) { $0 + $1.openAssignmentCount }
        return LazyVGrid(columns: AdaptiveGrid.adaptive(min: 150), spacing: 18) {
            KPITile(title: "Plantas", value: Fmt.int(plants.count), symbol: "building.2.fill")
            KPITile(
                title: "Capacidad mensual total", value: Fmt.money(capacity, compact: true), symbol: "gauge.with.dots.needle.67percent",
                tint: Theme.info)
            KPITile(
                title: "Usado este mes", value: Fmt.money(used, compact: true), symbol: "chart.bar.fill",
                tint: CapacityBar.tint(for: capacity > 0 ? used / capacity : 0),
                footnote: capacity > 0 ? "\(Fmt.percent(used / capacity)) de la capacidad" : nil)
            KPITile(title: "Asignaciones activas", value: Fmt.int(active), symbol: "scissors", tint: Theme.thread)
        }
    }

    private func delete(_ plant: Plant) {
        let name = plant.displayName
        do {
            try session.service.delete(plant)
            toasts.show("Planta «\(name)» eliminada")
        } catch {
            toasts.error(error)
        }
    }
}

/// Sheet target: either a new plant or an existing one.
enum PlantEditorTarget: Identifiable {
    case new
    case edit(Plant)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let plant): plant.objectID.uriRepresentation().absoluteString
        }
    }

    var plant: Plant? {
        if case .edit(let plant) = self { return plant }
        return nil
    }
}

struct PlantCard: View {
    @ObservedObject var plant: Plant

    var body: some View {
        let now = Date.now
        let ledger = plant.ledger
        let used = ledger.used(inMonthOf: now)
        let available = ledger.available(inMonthOf: now)
        let ratio = ledger.utilization(inMonthOf: now)
        let managers = plant.plantManagers

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                AvatarView(name: plant.displayName, size: 50, symbol: "building.2.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text(plant.displayName).font(.title3.weight(.bold)).lineLimit(1)
                    Text("Capacidad \(Fmt.money(plant.maxCapacity, compact: true)) al mes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Text(Fmt.percent(ratio))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(CapacityBar.tint(for: ratio))
                    .contentTransition(.numericText())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Date.now.formatted(.dateTime.month(.wide)).capitalized).font(.caption.weight(.semibold))
                    Spacer()
                    Text("Disponible \(Fmt.money(max(0, available), compact: true))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                CapacityBar(used: used, max: plant.maxCapacity)
                Text("Usado \(Fmt.money(used, compact: true))").font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .center) {
                CardStat(symbol: "scissors", value: Fmt.int(plant.openAssignmentCount), label: "activas", tint: Theme.thread)
                Spacer()
                ManagersStack(managers: managers)
            }
        }
        .card()
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el detalle de la planta")
    }
}

/// Overlapping avatars of a plant's managers.
struct ManagersStack: View {
    var managers: [AppUser]

    var body: some View {
        if managers.isEmpty {
            Label("Sin gerente", systemImage: "person.crop.circle.badge.questionmark")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(managers.prefix(3), id: \.objectID) { user in
                        AvatarView(name: user.fullName, imageData: user.avatarData, size: 30)
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.surface, lineWidth: 2)
                            }
                    }
                }
                (managers.count == 1 ? Text(managers[0].fullName) : Text("\(managers.count) gerentes"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct PlantEditorSheet: View {
    var plant: Plant?

    @Environment(\.managedObjectContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var capacity: Double = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        FormSheet(
            title: plant == nil ? "Nueva planta" : "Editar planta",
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty && capacity > 0,
            onSave: save
        ) {
            Section {
                TextField("Nombre", text: $name)
                    .focused($nameFocused)
                    .submitLabel(.next)
                DecimalField(title: "Capacidad máxima mensual", value: $capacity, currency: true)
            } header: {
                Text("Planta")
            } footer: {
                Text("La capacidad se mide en pesos por mes: cada asignación consume cantidad × precio unitario.")
            }

            if let plant, plant.maxCapacity > 0 {
                Section("Este mes") {
                    let used = plant.ledger.used(inMonthOf: .now)
                    VStack(alignment: .leading, spacing: 8) {
                        CapacityBar(used: used, max: capacity)
                        HStack {
                            Text("Usado \(Fmt.money(used))")
                            Spacer()
                            Text("Disponible \(Fmt.money(max(0, capacity - used)))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if used > capacity {
                            Label("La nueva capacidad es menor a lo ya asignado este mes.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            name = plant?.name ?? ""
            capacity = plant?.maxCapacity ?? 0
            if plant == nil { nameFocused = true }
        }
    }

    private func save() {
        do {
            let saved = try CatalogService(context: context).savePlant(plant, name: name, maxCapacity: capacity)
            toasts.show(plant == nil ? "Planta «\(saved.displayName)» creada" : "Planta actualizada")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

extension Plant {
    /// Users with the plant-manager role linked to this plant.
    var plantManagers: [AppUser] {
        (managers as? Set<AppUser> ?? []).filter { $0.role == .plantManager }.sorted { $0.fullName < $1.fullName }
    }

    /// Assignments still in progress (garments pending shipment).
    var openAssignmentCount: Int { assignmentList.filter { !$0.metrics.isComplete }.count }
}

#Preview("Plantas") {
    NavigationStack { PlantsView() }
        .catalogPreviewEnvironment()
}
