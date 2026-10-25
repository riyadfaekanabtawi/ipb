import CoreData
import SwiftUI

/// Production cost calculator. All formulas live in `CalculatorEngine`; this screen only
/// collects inputs and renders live results (the legacy screen required pressing return and crashed on empty fields).
struct CalculatorView: View {
    @Environment(ToastCenter.self) private var toasts
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]) private var plants: FetchedResults<Plant>

    @State private var client = ""
    @State private var plantID: NSManagedObjectID?
    @State private var input = CalculatorInput()
    @State private var constants = CalculatorConstants.load()
    @State private var showConstants = false

    private var result: CalculatorResult { CalculatorEngine.compute(input, constants: constants) }

    var body: some View {
        let result = result
        let summary = Self.summary(client: client, plant: plantName, input: input, result: result)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !constants.isComplete {
                    ConstantsBanner { showConstants = true }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        inputs.frame(width: 420)
                        CalculatorResults(result: result, constants: constants)
                    }
                    .frame(minWidth: 940)
                    VStack(spacing: 20) {
                        inputs
                        CalculatorResults(result: result, constants: constants)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1_400)
            .frame(maxWidth: .infinity)
            .animation(.spring(duration: 0.4), value: constants.isComplete)
        }
        .scrollDismissesKeyboard(.interactively)
        .tramaScreenBackground()
        .navigationTitle("Calculadora")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Constantes", systemImage: "slider.horizontal.3") { showConstants = true }
                Menu {
                    Button("Copiar resumen", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = summary
                        toasts.show("Resumen copiado")
                    }
                    ShareLink(item: summary, subject: Text("Cálculo de producción")) {
                        Label("Compartir resumen", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
                .disabled(result.grossIncome == nil && result.dailyGoal == nil)
                Button("Limpiar", systemImage: "eraser", role: .destructive, action: clear)
            }
        }
        .sheet(isPresented: $showConstants) {
            ConstantsSheet(constants: constants) { updated in
                updated.save()
                withAnimation(.spring) { constants = updated }
                toasts.show("Constantes guardadas")
            }
        }
    }

    private var plantName: String? {
        plantID.flatMap { id in plants.first { $0.objectID == id }?.displayName }
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                CalcSectionTitle(title: "Estilo", symbol: "tshirt.fill")
                VStack(spacing: 0) {
                    LabeledContent {
                        TextField("Nombre del cliente", text: $client)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                    } label: {
                        Label("Cliente", systemImage: "person.2")
                    }
                    .calcRow()
                    Divider()
                    LabeledContent {
                        Picker("Planta", selection: $plantID) {
                            Text("Sin planta").tag(NSManagedObjectID?.none)
                            ForEach(plants, id: \.objectID) { plant in
                                Text(plant.displayName).tag(Optional(plant.objectID))
                            }
                        }
                        .labelsHidden()
                    } label: {
                        Label("Planta", systemImage: "building.2")
                    }
                    .calcRow()
                    row("Cantidad del estilo", "number", $input.quantity, unit: "prendas")
                    row("Minutaje real", "stopwatch", $input.realMinutes, unit: "min")
                    row("Minutaje cliente", "person.badge.clock", $input.clientMinutes, unit: "min")
                    row("Operarios", "person.3", $input.operators)
                    row("Precio unitario interno", "tag", $input.internalUnitPrice, unit: "MXN")
                    row("Precio por estilo", "dollarsign.circle", $input.pricePerStyle, unit: "MXN")
                    row("Gastos operativos", "creditcard", $input.operatingExpenses, unit: "MXN")
                }
            }
            .card(padding: 18)

            VStack(alignment: .leading, spacing: 0) {
                CalcSectionTitle(title: "Minuto real de producción", symbol: "gauge.with.dots.needle.67percent")
                VStack(spacing: 0) {
                    row("Operarios de línea", "person.3.sequence", $input.lineOperators, divider: false)
                    row("Producción real diaria", "chart.line.uptrend.xyaxis", $input.realDailyProduction, unit: "prendas")
                }
            }
            .card(padding: 18)
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ symbol: String, _ value: Binding<Double>, unit: String? = nil, divider: Bool = true) -> some View {
        if divider { Divider() }
        LiveNumberField(title: title, symbol: symbol, value: value, unit: unit).calcRow()
    }

    private func clear() {
        withAnimation(.spring) {
            client = ""
            plantID = nil
            input = CalculatorInput()
        }
        toasts.show("Calculadora limpia", style: .info)
    }

    /// Plain-text summary for the pasteboard / share sheet.
    static func summary(client: String, plant: String?, input: CalculatorInput, result: CalculatorResult) -> String {
        func money(_ v: Double?) -> String { v.map { Fmt.money($0) } ?? "—" }
        func num(_ v: Double?, _ unit: String) -> String { v.map { "\(Fmt.number($0)) \(unit)" } ?? "—" }
        var lines = ["Cálculo de producción · Trama"]
        if !client.isEmpty { lines.append("Cliente: \(client)") }
        if let plant { lines.append("Planta: \(plant)") }
        lines += [
            "Cantidad: \(Fmt.int(Int(input.quantity))) prendas · Minutaje real \(Fmt.number(input.realMinutes, digits: 2)) · cliente \(Fmt.number(input.clientMinutes, digits: 2))",
            "Operarios: \(Fmt.int(Int(input.operators))) · Precio por estilo \(Fmt.money(input.pricePerStyle)) · Gastos \(Fmt.money(input.operatingExpenses))",
            "",
            "Ingreso bruto: \(money(result.grossIncome))",
            "Ingreso neto: \(money(result.netIncome))",
            "Precio por minuto real: \(money(result.pricePerRealMinute))",
            "Meta diaria: \(num(result.dailyGoal, "prendas"))",
            "Producción semanal: \(num(result.weeklyProduction, "prendas"))",
            "Días estimados: \(num(result.estimatedDays, "días"))",
            "Meses estimados: \(num(result.estimatedMonths, "meses"))",
            "Eficiencia de minutaje: \(result.minuteEfficiency.map(Fmt.percent) ?? "—")",
            "Minuto real de producción: \(num(result.realProductionMinute, "min"))",
        ]
        return lines.joined(separator: "\n")
    }
}

// MARK: - Results

private struct CalculatorResults: View {
    var result: CalculatorResult
    var constants: CalculatorConstants

    private let columns = AdaptiveGrid.adaptive(min: 210, spacing: 14)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IncomeCard(title: "Ingreso bruto", value: result.grossIncome, symbol: "banknote", emphasized: false)
                IncomeCard(title: "Ingreso neto", value: result.netIncome, symbol: "chart.line.uptrend.xyaxis", emphasized: true)
            }
            LazyVGrid(columns: columns, spacing: 14) {
                ResultCard(
                    title: "Precio por minuto real", value: result.pricePerRealMinute.map { Fmt.money($0) },
                    symbol: "stopwatch", tint: Theme.brand, hint: "Precio por estilo ÷ minutaje real")
                ResultCard(
                    title: "Meta diaria", value: result.dailyGoal.map { Fmt.number($0) }, unit: "prendas",
                    symbol: "target", tint: Theme.info,
                    hint: needsConstants ? "Requiere minutos por día" : "Operarios × minutos día ÷ minutaje")
                ResultCard(
                    title: "Producción semanal", value: result.weeklyProduction.map { Fmt.number($0) }, unit: "prendas",
                    symbol: "calendar.badge.clock", tint: Theme.info, hint: "Meta diaria × días por semana")
                ResultCard(
                    title: "Días estimados", value: result.estimatedDays.map { Fmt.number($0) }, unit: "días",
                    symbol: "calendar", tint: Theme.warning, hint: "Cantidad ÷ meta diaria")
                ResultCard(
                    title: "Meses estimados", value: result.estimatedMonths.map { Fmt.number($0, digits: 2) }, unit: "meses",
                    symbol: "calendar.circle", tint: Theme.warning, hint: "Días ÷ días por mes")
                EfficiencyCard(efficiency: result.minuteEfficiency)
                ResultCard(
                    title: "Minuto real de producción", value: result.realProductionMinute.map { Fmt.number($0, digits: 2) }, unit: "min",
                    symbol: "gauge.with.dots.needle.67percent", tint: Theme.success, hint: "Minutos día × operarios ÷ producción diaria")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var needsConstants: Bool { constants.minutesPerDay <= 0 }
}

private struct IncomeCard: View {
    var title: String
    var value: Double?
    var symbol: String
    var emphasized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .opacity(0.85)
            Text(value.map { Fmt.money($0) } ?? "—")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(emphasized && (value ?? 0) < 0 ? Theme.danger : (emphasized ? .white : .primary))
            Text(emphasized ? "Bruto − gastos operativos" : "Cantidad × precio por estilo")
                .font(.caption)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(emphasized ? .white : .primary)
        .padding(20)
        .background {
            if emphasized {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.brandGradient)
            } else {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.surface)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.stroke))
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
        .animation(.spring(duration: 0.35), value: value)
        .accessibilityElement(children: .combine)
    }
}

private struct ResultCard: View {
    var title: String
    var value: String?
    var unit: String?
    var symbol: String
    var tint: Color
    var hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 11, style: .continuous))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(value == nil ? .tertiary : .primary)
                if let unit, value != nil {
                    Text(unit).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
            }
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Text(hint).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
        .animation(.spring(duration: 0.35), value: value)
        .accessibilityElement(children: .combine)
    }
}

private struct EfficiencyCard: View {
    var efficiency: Double?

    private var tint: Color {
        guard let efficiency else { return .secondary }
        return efficiency >= 1 ? Theme.success : efficiency >= 0.85 ? Theme.warning : Theme.danger
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: efficiency ?? 0, tint: tint, lineWidth: 7)
                Image(systemName: "percent").font(.caption.weight(.bold)).foregroundStyle(tint)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(efficiency.map(Fmt.percent) ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(efficiency == nil ? .tertiary : .primary)
                Text("Eficiencia de minutaje").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Text("Minutaje cliente ÷ real").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .card(padding: 16)
        .animation(.spring(duration: 0.35), value: efficiency)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Constants

private struct ConstantsBanner: View {
    var action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "slider.horizontal.3")
                .font(.title3)
                .foregroundStyle(Theme.warning)
                .frame(width: 44, height: 44)
                .background(Theme.warning.opacity(0.15), in: .rect(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Configura las constantes de planta").font(.headline)
                Text(
                    "Minutos por operario y días de trabajo son necesarios para la meta diaria, la producción semanal y los tiempos estimados."
                )
                .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Configurar", action: action)
                .buttonStyle(.borderedProminent)
                .tint(Theme.warning)
        }
        .card(padding: 16)
    }
}

private struct ConstantsSheet: View {
    @State var constants: CalculatorConstants
    var onSave: (CalculatorConstants) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FormSheet(
            title: "Constantes",
            onSave: {
                onSave(constants)
                dismiss()
            }
        ) {
            Section {
                LiveNumberField(title: "Minutos por día", value: $constants.minutesPerDay, unit: "min")
                LiveNumberField(title: "Minutos por semana", value: $constants.minutesPerWeek, unit: "min")
                LiveNumberField(title: "Minutos por mes", value: $constants.minutesPerMonth, unit: "min")
            } header: {
                Text("Por operario")
            }
            Section {
                LiveNumberField(title: "Días de trabajo por semana", value: $constants.workDaysPerWeek, unit: "días")
                LiveNumberField(title: "Días de trabajo por mes", value: $constants.workDaysPerMonth, unit: "días")
            } header: {
                Text("Calendario")
            } footer: {
                Text("Se guardan en este iPad y se usan en todos los cálculos.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CalcSectionTitle: View {
    var title: String
    var symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(Theme.brand)
            .padding(.bottom, 8)
    }
}

private extension View {
    func calcRow() -> some View {
        frame(minHeight: 46).font(.body)
    }
}

#Preview("Calculadora") {
    let persistence = PersistenceController.preview
    return NavigationStack { CalculatorView() }
        .environment(\.managedObjectContext, persistence.viewContext)
        .environment(Session(context: persistence.viewContext))
        .environment(ToastCenter())
        .environment(AppRouter())
        .environment(ConnectivityMonitor())
}
