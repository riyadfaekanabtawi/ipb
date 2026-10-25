import SwiftUI

struct StylesView: View {
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Style.name, ascending: true)])
    private var styles: FetchedResults<Style>

    enum SortOrder: String, CaseIterable, Identifiable {
        case name = "Nombre"
        case orders = "Más cortes"
        case recent = "Recientes"
        var id: String { rawValue }
    }

    @State private var search = ""
    @State private var sort: SortOrder = .name
    @State private var editor: StyleEditorTarget?
    @State private var pendingDelete: Style?
    @State private var zoomed: Style?

    private var visible: [Style] {
        let matches = styles.filter { CatalogSearch.matches(search, [$0.name] + $0.plantDistribution.map(\.plant.name)) }
        switch sort {
        case .name: return matches
        case .orders: return matches.sorted { ($0.orders?.count ?? 0) > ($1.orders?.count ?? 0) }
        case .recent: return matches.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
    }

    var body: some View {
        Group {
            if styles.isEmpty {
                ContentUnavailableView {
                    Label("Sin estilos", systemImage: "tshirt")
                } description: {
                    Text("Fotografía tus estilos para reconocerlos al instante en cortes y producción.")
                } actions: {
                    Button("Nuevo estilo", systemImage: "camera") { editor = .new }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 60)
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 200, spacing: 20), spacing: 22) {
                    ForEach(visible, id: \.objectID) { style in
                        NavigationLink(value: Route.style(style.objectID)) {
                            StyleCard(style: style) { zoomed = style }
                        }
                        .buttonStyle(StyleCardButtonStyle())
                        .contextMenu {
                            Button("Ver imagen", systemImage: "arrow.up.left.and.arrow.down.right") { zoomed = style }
                            Button("Editar", systemImage: "pencil") { editor = .edit(style) }
                            Divider()
                            Button("Eliminar", systemImage: "trash", role: .destructive) { pendingDelete = style }
                        } preview: {
                            SwatchImage(data: style.imageData, name: style.displayName, cornerRadius: 0)
                                .frame(width: 420, height: 520)
                        }
                    }
                }
                .animation(.spring(duration: 0.4), value: visible.map(\.objectID))
            }
        }
        .catalogScroll()
        .navigationTitle("Estilos")
        .searchable(text: $search, prompt: "Buscar estilo o planta")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Picker("Ordenar", selection: $sort) {
                    ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            AddToolbarButton(title: "Nuevo estilo") { editor = .new }
        }
        .sheet(item: $editor) { target in StyleEditorSheet(style: target.style) }
        .fullScreenCover(item: $zoomed) { style in
            ZoomableImageViewer(data: style.imageData, title: style.displayName)
        }
        .confirmDelete(
            "¿Eliminar \(pendingDelete?.displayName ?? "estilo")?", item: $pendingDelete,
            message: "Los cortes que lo usan quedarán sin estilo."
        ) { style in
            let name = style.displayName
            do {
                try session.service.delete(style)
                toasts.show("Estilo «\(name)» eliminado")
            } catch {
                toasts.error(error)
            }
        }
    }
}

enum StyleEditorTarget: Identifiable {
    case new
    case edit(Style)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let style): style.objectID.uriRepresentation().absoluteString
        }
    }

    var style: Style? {
        if case .edit(let style) = self { return style }
        return nil
    }
}

private struct StyleCard: View {
    @ObservedObject var style: Style
    var zoom: () -> Void

    var body: some View {
        let distribution = style.plantDistribution
        let orderCount = style.orders?.count ?? 0

        VStack(alignment: .leading, spacing: 0) {
            SwatchImage(data: style.imageData, name: style.displayName, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.displayName)
                                .font(.headline)
                                .lineLimit(2)
                            Text(orderCount == 1 ? "1 corte" : "\(orderCount) cortes")
                                .font(.caption.weight(.medium))
                                .opacity(0.85)
                        }
                        .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        if style.imageData != nil {
                            Button(action: zoom) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.footnote.weight(.bold))
                                    .frame(width: 34, height: 34)
                                    .background(.ultraThinMaterial, in: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ver imagen de \(style.displayName)")
                        }
                    }
                    .padding(14)
                }
                .clipped()

            Group {
                if distribution.isEmpty {
                    Text("Sin asignar a plantas")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    FlowRow(spacing: 6) {
                        ForEach(distribution, id: \.plant.objectID) { entry in
                            Pill(
                                text: "\(entry.plant.displayName): \(entry.count)", symbol: "building.2",
                                tint: Theme.accent(for: entry.plant.displayName))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .padding(14)
        }
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: Theme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.stroke)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
        .contentShape(.rect(cornerRadius: Theme.radius))
    }
}

/// Gentle press-down for the image cards.
private struct StyleCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct StyleEditorSheet: View {
    var style: Style?

    @Environment(\.managedObjectContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var imageData: Data?
    @State private var loaded = false

    var body: some View {
        FormSheet(
            title: style == nil ? "Nuevo estilo" : "Editar estilo",
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
            onSave: save
        ) {
            Section {
                SwatchImage(data: imageData, name: name.isEmpty ? "Estilo" : name, cornerRadius: Theme.smallRadius)
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .animation(.smooth, value: imageData)
            }
            Section("Estilo") {
                TextField("Nombre o clave (p. ej. Falda plisada SK-210)", text: $name)
            }
            Section("Foto") {
                PhotoField(title: name.isEmpty ? "Estilo" : name, data: $imageData)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = style?.name ?? ""
            imageData = style?.imageData
        }
    }

    private func save() {
        do {
            let saved = try CatalogService(context: context).saveStyle(style, name: name, imageData: imageData)
            toasts.show(style == nil ? "Estilo «\(saved.displayName)» creado" : "Estilo actualizado")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

#Preview("Estilos") {
    NavigationStack { StylesView() }
        .catalogPreviewEnvironment()
}
