import CoreData
import Observation
import SwiftUI

/// Drives one legacy import run and exposes its progress to the UI.
@MainActor
@Observable
final class LegacyImportModel {
    enum Phase: Equatable {
        case idle
        case running(step: Int, total: Int, resource: LegacyResource)
        case finished(LegacyImportSummary)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    var isRunning: Bool { if case .running = phase { true } else { false } }

    func run(baseURL: String, context: NSManagedObjectContext) async {
        do {
            let client = try LegacyAPIClient(baseString: baseURL)
            let importer = LegacyImporter(context: context)
            phase = .running(step: 0, total: LegacyResource.allCases.count, resource: .plants)
            let summary = try await importer.run(from: client) { [weak self] step, total, resource in
                withAnimation(.smooth) { self?.phase = .running(step: step, total: total, resource: resource) }
            }
            withAnimation(.spring) { phase = .finished(summary) }
        } catch {
            // Rows already saved per step stay; re-running upserts the rest.
            context.rollback()
            withAnimation(.spring) { phase = .failed(error.localizedDescription) }
        }
    }
}

struct LegacyImportPanel: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(ConnectivityMonitor.self) private var connectivity
    @AppStorage("legacy.baseURL") private var baseURL = ""
    @State private var model = LegacyImportModel()
    @State private var confirmImport = false

    var body: some View {
        LabeledContent {
            TextField("servidor-anterior.com", text: $baseURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .disabled(model.isRunning)
        } label: {
            Label("Servidor", systemImage: "server.rack")
        }

        Button {
            confirmImport = true
        } label: {
            SettingsActionRow(
                title: "Importar del sistema anterior",
                subtitle: baseURL.isEmpty
                    ? "Configura la dirección del servidor para activarlo"
                    : (connectivity.isOnline ? "Requiere conexión a internet" : "Sin conexión"),
                symbol: "arrow.down.circle", tint: Theme.info)
        }
        .disabled(baseURL.trimmingCharacters(in: .whitespaces).isEmpty || model.isRunning || !connectivity.isOnline)
        .confirmationDialog("¿Importar del sistema anterior?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Importar") { start() }
        } message: {
            Text(
                "Se agregan o actualizan registros; nada local se borra. Los usuarios importados quedan inactivos hasta asignarles contraseña."
            )
        }

        switch model.phase {
        case .idle:
            EmptyView()
        case .running(let step, let total, let resource):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Importando \(resource.title.lowercased())…", systemImage: resource.symbol)
                        .font(.subheadline.weight(.medium))
                        .contentTransition(.interpolate)
                    Spacer()
                    Text("\(step)/\(total)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(step), total: Double(max(total, 1)))
                    .tint(Theme.brand)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        case .finished(let summary):
            LegacyImportResult(summary: summary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.octagon.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.danger)
        }
    }

    private func start() {
        Task {
            await model.run(baseURL: baseURL, context: context)
            switch model.phase {
            case .finished(let summary):
                toasts.show("Importación completa: \(Fmt.int(summary.totalCreated)) nuevos, \(Fmt.int(summary.totalUpdated)) actualizados")
            case .failed(let message):
                toasts.show(message, style: .error)
            default: break
            }
        }
    }
}

private struct LegacyImportResult: View {
    var summary: LegacyImportSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Importación completa", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.success)
            LazyVGrid(columns: AdaptiveGrid.adaptive(min: 160, spacing: 10), alignment: .leading, spacing: 10) {
                ForEach(LegacyResource.allCases) { resource in
                    let count = summary[resource]
                    HStack(spacing: 8) {
                        Image(systemName: resource.symbol).foregroundStyle(Theme.brand).frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(resource.title): \(Fmt.int(count.total))").font(.caption.weight(.semibold))
                            Text(detail(count)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if summary.imagesDownloaded > 0 {
                Text("\(Fmt.int(summary.imagesDownloaded)) imágenes descargadas").font(.caption).foregroundStyle(.secondary)
            }
            if summary[.users].created > 0 {
                Label(
                    "\(summary[.users].created) usuarios nuevos quedaron inactivos. Asígnales contraseña y actívalos en Usuarios.",
                    systemImage: "person.badge.key"
                )
                .font(.caption)
                .foregroundStyle(Theme.warning)
            }
        }
        .padding(.vertical, 4)
    }

    private func detail(_ count: LegacyImportSummary.Count) -> String {
        var parts = ["\(count.created) nuevos", "\(count.updated) act."]
        if count.skipped > 0 { parts.append("\(count.skipped) omitidos") }
        return parts.joined(separator: " · ")
    }
}
