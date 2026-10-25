import CoreData
import SwiftUI

/// "Cortes por asignar": all cut orders with their assignment progress.
struct OrdersView: View {
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [SortDescriptor(\CutOrder.clientDate), SortDescriptor(\CutOrder.code)])
    private var orders: FetchedResults<CutOrder>

    @State private var filter: Filter = .pending
    @State private var query = ""
    @State private var editing: CutOrder?
    @State private var creating = false
    @State private var deleting: CutOrder?

    enum Filter: String, CaseIterable, Identifiable {
        case pending, all, assigned
        var id: String { rawValue }
        var title: String {
            switch self {
            case .pending: String(localized: "Por asignar")
            case .all: String(localized: "Todos")
            case .assigned: String(localized: "Asignados")
            }
        }
    }

    private var filtered: [CutOrder] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return orders.filter { order in
            let matchesFilter: Bool
            switch filter {
            case .pending: matchesFilter = order.remainingQuantity > 0
            case .assigned: matchesFilter = order.assignmentState == .assigned
            case .all: matchesFilter = true
            }
            return matchesFilter && (q.isEmpty || order.searchableText.contains(q))
        }
    }

    var body: some View {
        let pending = orders.filter { $0.remainingQuantity > 0 }
        let garments = pending.reduce(0) { $0 + $1.remainingQuantity }
        let value = pending.reduce(0.0) { $0 + Double($1.remainingQuantity) * $1.unitPrice }
        let rows = filtered

        List {
            Section {
                HStack(spacing: 16) {
                    KPITile(title: "Cortes pendientes", value: Fmt.int(pending.count), symbol: "scissors", tint: Theme.danger)
                    KPITile(title: "Prendas por asignar", value: Fmt.int(garments), symbol: "tshirt", tint: Theme.warning)
                    KPITile(title: "Valor por asignar", value: Fmt.money(value, compact: true), symbol: "banknote", tint: Theme.brand)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                if rows.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "No hay cortes aquí" : "Sin resultados",
                        systemImage: query.isEmpty ? "checkmark.seal" : "magnifyingglass",
                        description: Text(
                            query.isEmpty ? "Todos los cortes de este filtro están al día." : "Prueba con otro código, lista o cliente.")
                    )
                    .listRowBackground(Color.clear)
                }
                ForEach(rows) { order in
                    NavigationLink(value: Route.order(order.objectID)) {
                        OrderRow(order: order)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Eliminar", systemImage: "trash", role: .destructive) { deleting = order }
                        Button("Editar", systemImage: "pencil") { editing = order }.tint(Theme.brand)
                    }
                    .contextMenu {
                        Button("Editar", systemImage: "pencil") { editing = order }
                        Button("Eliminar", systemImage: "trash", role: .destructive) { deleting = order }
                    }
                }
            } header: {
                Picker("Filtro", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                .padding(.bottom, 6)
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .tramaScreenBackground()
        .searchable(text: $query, prompt: "Código, lista, cliente, estilo…")
        .navigationTitle("Cortes por asignar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label("Nuevo corte", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $creating) { OrderEditorSheet(order: nil) }
        .sheet(item: $editing) { OrderEditorSheet(order: $0) }
        .confirmDelete(
            "¿Eliminar el corte \(deleting?.displayCode ?? "")?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            message: "Se eliminarán también sus asignaciones sin reportes."
        ) {
            guard let order = deleting else { return }
            do {
                try session.service.delete(order)
                toasts.show("Corte eliminado")
            } catch { toasts.error(error) }
            deleting = nil
        }
    }
}

/// Create/edit a cut order. The legacy app received these from the server; now they're entered here.
struct OrderEditorSheet: View {
    var order: CutOrder?

    @Environment(\.dismiss) private var dismiss
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [SortDescriptor(\Client.name)]) private var clients: FetchedResults<Client>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Style.name)]) private var styles: FetchedResults<Style>

    @State private var code = ""
    @State private var list = ""
    @State private var garment = ""
    @State private var quantity = 0
    @State private var unitPrice = 0.0
    @State private var client: Client?
    @State private var style: Style?
    @State private var hasInternalDate = true
    @State private var internalDate = Date()
    @State private var hasClientDate = true
    @State private var clientDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var notes = ""
    @State private var loaded = false

    private var canSave: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0 && unitPrice >= 0
            && quantity >= (order?.assignedQuantity ?? 0)
    }

    var body: some View {
        FormSheet(title: order == nil ? "Nuevo corte" : "Editar corte", canSave: canSave, onSave: save) {
            Section("Identificación") {
                TextField("Código de corte", text: $code)
                    .textInputAutocapitalization(.characters)
                TextField("Lista", text: $list)
                    .textInputAutocapitalization(.characters)
                TextField("Prenda (ej. Falda, Jeans)", text: $garment)
            }
            Section("Cliente y estilo") {
                Picker("Cliente", selection: $client) {
                    Text("Sin cliente").tag(Client?.none)
                    ForEach(clients) { Text($0.displayName).tag(Optional($0)) }
                }
                Picker("Estilo", selection: $style) {
                    Text("Sin estilo").tag(Style?.none)
                    ForEach(styles) { Text($0.displayName).tag(Optional($0)) }
                }
            }
            Section {
                IntField(title: "Cantidad", value: $quantity)
                DecimalField(title: "Precio unitario", value: $unitPrice, currency: true)
                LabeledContent("Ingreso total", value: Fmt.money(Double(quantity) * unitPrice))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Cantidad y precio")
            } footer: {
                if let order, quantity < order.assignedQuantity {
                    Text("Ya hay \(order.assignedQuantity) prendas asignadas; la cantidad no puede ser menor.")
                        .foregroundStyle(Theme.danger)
                }
            }
            Section("Fechas") {
                Toggle("Fecha interna", isOn: $hasInternalDate.animation())
                if hasInternalDate { DatePicker("Fecha interna", selection: $internalDate, displayedComponents: .date) }
                Toggle("Fecha cliente", isOn: $hasClientDate.animation())
                if hasClientDate { DatePicker("Fecha de entrega al cliente", selection: $clientDate, displayedComponents: .date) }
            }
            Section("Notas") {
                TextField("Notas", text: $notes, axis: .vertical).lineLimit(3...6)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let order else { return }
        code = order.code ?? ""
        list = order.list ?? ""
        garment = order.garment ?? ""
        quantity = Int(order.quantity)
        unitPrice = order.unitPrice
        client = order.client
        style = order.style
        hasInternalDate = order.internalDate != nil
        internalDate = order.internalDate ?? .now
        hasClientDate = order.clientDate != nil
        clientDate = order.clientDate ?? .now
        notes = order.notes ?? ""
    }

    private func save() {
        let service = session.service
        do {
            if let order {
                try service.update(
                    order, code: code, list: list, garment: garment, quantity: quantity, unitPrice: unitPrice,
                    client: client, style: style, internalDate: hasInternalDate ? internalDate : nil,
                    clientDate: hasClientDate ? clientDate : nil, notes: notes.isEmpty ? nil : notes)
                toasts.show("Corte \(code) actualizado")
            } else {
                try service.createOrder(
                    code: code, list: list, garment: garment, quantity: quantity, unitPrice: unitPrice,
                    client: client, style: style, internalDate: hasInternalDate ? internalDate : nil,
                    clientDate: hasClientDate ? clientDate : nil, notes: notes.isEmpty ? nil : notes)
                toasts.show("Corte \(code) creado")
            }
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

#Preview {
    let persistence = PersistenceController.preview
    return NavigationStack { OrdersView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(Session(context: persistence.viewContext))
        .environment(ToastCenter())
        .environment(AppRouter())
}
