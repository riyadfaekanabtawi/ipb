import CoreData
import SwiftUI

/// Create or edit one of the three report kinds for an assignment.
struct ReportEditorSheet: View {
    @ObservedObject var assignment: Assignment
    var kind: ReportKind
    var report: ProductionReport?

    @Environment(\.dismiss) private var dismiss
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    // Plant
    @State private var plant = ProductionService.PlantReportInput()
    // Cut
    @State private var cutStatus: CutStatus = .waiting
    @State private var realQuantity = 0
    // Shipment
    @State private var shipmentNumber = ""
    @State private var shippedQuantity = 0
    @State private var loaded = false

    private var metrics: AssignmentMetrics { assignment.metrics }

    var body: some View {
        FormSheet(
            title: (report == nil ? "" : "Editar ") + kind.title.lowercased().capitalizedFirst,
            saveTitle: report == nil ? "Cargar" : "Guardar", canSave: canSave, onSave: save
        ) {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: kind.symbol)
                        .font(.title2)
                        .foregroundStyle(kind.tint)
                        .frame(width: 48, height: 48)
                        .background(kind.tint.opacity(0.14), in: .rect(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Corte \(assignment.title)").font(.headline)
                        Text(
                            "\(assignment.plantName) · \(Fmt.int(Int(assignment.quantity))) prendas · \(Date.now.formatted(.dateTime.day().month().hour().minute()))"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            switch kind {
            case .plant: plantFields
            case .cut: cutFields
            case .shipment: shipmentFields
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Fields

    @ViewBuilder private var plantFields: some View {
        Section("Personal") {
            IntField(title: "Operarios", value: $plant.operators)
            IntField(title: "Faltas", value: $plant.absences)
        }
        Section {
            IntField(title: "Prendas producidas", value: $plant.produced)
            IntField(title: "En plancha", value: $plant.ironing)
            IntField(title: "En empaque", value: $plant.packing)
            IntField(title: "En bodega", value: $plant.warehouse)
        } header: {
            Text("Avance")
        } footer: {
            Text("Captura el estado actual de la planta. El último reporte reemplaza a los anteriores en los totales.")
        }
    }

    @ViewBuilder private var cutFields: some View {
        Section("Estado del corte") {
            Picker("Estado", selection: $cutStatus) {
                ForEach(CutStatus.allCases) { status in
                    Label(status.title, systemImage: status.symbol).tag(status)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        Section {
            IntField(title: "Cantidad real cortada", value: $realQuantity)
        } footer: {
            Text(
                "Solo hay un reporte de corte por asignación. Si la cantidad real difiere de las \(Fmt.int(Int(assignment.quantity))) planeadas, los envíos se miden contra la real."
            )
        }
    }

    @ViewBuilder private var shipmentFields: some View {
        Section {
            TextField("Número de envío", text: $shipmentNumber)
                .textInputAutocapitalization(.characters)
            IntField(title: "Cantidad enviada", value: $shippedQuantity)
        } header: {
            Text("Envío")
        } footer: {
            let pending = metrics.toShip + Int(report?.shippedQuantity ?? 0)
            Text("Pendientes por enviar: \(Fmt.int(pending)).")
                .foregroundStyle(shippedQuantity > pending ? Theme.warning : .secondary)
        }
    }

    // MARK: Logic

    private var canSave: Bool {
        switch kind {
        case .plant: true
        case .cut: realQuantity >= 0
        case .shipment: !shipmentNumber.trimmingCharacters(in: .whitespaces).isEmpty && shippedQuantity > 0
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let report {
            plant = .init(
                operators: Int(report.operators), absences: Int(report.absences), produced: Int(report.produced),
                ironing: Int(report.ironing), packing: Int(report.packing), warehouse: Int(report.warehouse))
            cutStatus = report.cutStatus ?? .waiting
            realQuantity = Int(report.realQuantity)
            shipmentNumber = report.shipmentNumber ?? ""
            shippedQuantity = Int(report.shippedQuantity)
        } else {
            // Pre-fill plant counters with the latest snapshot so managers only adjust what changed.
            let m = metrics
            plant = .init(
                operators: m.operators, absences: 0, produced: m.produced, ironing: m.ironing, packing: m.packing, warehouse: m.warehouse)
            cutStatus = assignment.cuttingStatus
            realQuantity = Int(assignment.quantity)
            let shipments = assignment.reportList.filter { $0.kind == .shipment }.count
            shipmentNumber = "\(shipments + 1)"
        }
    }

    private func save() {
        let service = session.service
        do {
            switch kind {
            case .plant:
                try service.addPlantReport(plant, to: assignment, editing: report)
            case .cut:
                try service.setCutReport(status: cutStatus, realQuantity: realQuantity, on: assignment, editing: report)
            case .shipment:
                try service.addShipmentReport(number: shipmentNumber, quantity: shippedQuantity, to: assignment, editing: report)
            }
            toasts.show(report == nil ? "Cargaste el \(kind.title.lowercased()) de \(assignment.title)" : "Reporte actualizado")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
