import CoreData
import SwiftUI

/// Quotes / prospects pipeline: pending → accepted or declined.
struct ProjectsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(Session.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Project.createdAt, ascending: false)])
    private var projects: FetchedResults<Project>

    enum Layout: String { case board, grid }

    @AppStorage("projects.layout") private var layout: Layout = .board
    @State private var filter: ProjectStatus?
    @State private var search = ""
    @State private var editor: ProjectEditorTarget?
    @State private var pendingDelete: Project?

    private var matching: [Project] {
        projects.filter { CatalogSearch.matches(search, [$0.displayClient, $0.fabric, $0.notes]) }
    }

    var body: some View {
        let matching = matching
        VStack(alignment: .leading, spacing: 24) {
            if projects.isEmpty {
                ContentUnavailableView {
                    Label("Sin proyectos", systemImage: "folder")
                } description: {
                    Text("Registra cotizaciones y prospectos para darles seguimiento hasta que se acepten.")
                } actions: {
                    Button("Nuevo proyecto", systemImage: "plus") { editor = .new }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 60)
            } else {
                pipeline
                if layout == .board && filter == nil {
                    board(matching)
                } else {
                    filterPicker(matching)
                    grid(matching.filter { filter == nil || $0.status == filter })
                }
            }
        }
        .catalogScroll()
        .navigationTitle("Proyectos")
        .searchable(text: $search, prompt: "Buscar cliente, tela o notas")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Picker("Vista", selection: $layout.animation(.snappy)) {
                    Label("Tablero", systemImage: "rectangle.split.3x1").tag(Layout.board)
                    Label("Cuadrícula", systemImage: "square.grid.2x2").tag(Layout.grid)
                }
            }
            AddToolbarButton(title: "Nuevo proyecto") { editor = .new }
        }
        .sheet(item: $editor) { target in ProjectEditorSheet(project: target.project) }
        .confirmDelete("¿Eliminar este proyecto?", item: $pendingDelete, message: pendingDelete?.displayClient) { project in
            do {
                try session.service.delete(project)
                toasts.show("Proyecto eliminado")
            } catch {
                toasts.error(error)
            }
        }
    }

    // MARK: Pipeline KPIs

    private var pipeline: some View {
        LazyVGrid(columns: AdaptiveGrid.adaptive(min: 150), spacing: 18) {
            ForEach(ProjectStatus.allCases) { status in
                let group = projects.filter { $0.status == status }
                KPITile(
                    title: status.title,
                    value: Fmt.money(group.reduce(0) { $0 + $1.total }, compact: true),
                    symbol: status.symbol,
                    tint: status == .pending ? Theme.warning : status.tint,
                    footnote: group.count == 1 ? "1 proyecto" : "\(group.count) proyectos"
                ) {
                    withAnimation(.snappy) {
                        filter = filter == status ? nil : status
                        if filter != nil { layout = .grid }
                    }
                }
            }
            let accepted = projects.filter { $0.status == .accepted }.count
            let decided = projects.filter { $0.status != .pending }.count
            KPITile(
                title: "Tasa de aceptación", value: decided > 0 ? Fmt.percent(Double(accepted) / Double(decided)) : "—",
                symbol: "percent", tint: Theme.info, footnote: "De los proyectos ya decididos")
        }
    }

    private func filterPicker(_ matching: [Project]) -> some View {
        Picker("Estado", selection: $filter.animation(.snappy)) {
            Text("Todos (\(matching.count))").tag(ProjectStatus?.none)
            ForEach(ProjectStatus.allCases) { status in
                Text("\(status.title) (\(matching.filter { $0.status == status }.count))").tag(Optional(status))
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 640)
    }

    // MARK: Layouts

    private func grid(_ items: [Project]) -> some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? "Nada por aquí" : "Sin resultados", systemImage: "folder",
                    description: Text(search.isEmpty ? "No hay proyectos con este estado." : "Prueba con otra búsqueda."))
            } else {
                LazyVGrid(columns: AdaptiveGrid.adaptive(min: 300), spacing: 18) {
                    ForEach(items, id: \.objectID) { project in
                        card(project, compact: false)
                    }
                }
                .animation(.spring(duration: 0.4), value: items.map(\.objectID))
            }
        }
    }

    private func board(_ items: [Project]) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(ProjectStatus.allCases) { status in
                ProjectColumn(status: status, projects: items.filter { $0.status == status }) { project in
                    card(project, compact: true)
                } onDrop: { project in
                    setStatus(status, for: project)
                }
            }
        }
        .animation(.spring(duration: 0.4), value: items.map(\.statusRaw))
    }

    private func card(_ project: Project, compact: Bool) -> some View {
        // Tap gesture rather than a Button so the status Menu inside the card stays tappable.
        ProjectCard(project: project, compact: compact) { status in setStatus(status, for: project) }
            .onTapGesture { editor = .edit(project) }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Editar") { editor = .edit(project) }
            .draggable(project.objectID.uriRepresentation().absoluteString) {
                ProjectCard(project: project, compact: true) { _ in }
                    .frame(width: 260)
            }
            .contextMenu {
                Button("Editar", systemImage: "pencil") { editor = .edit(project) }
                Menu("Cambiar estado", systemImage: "arrow.triangle.2.circlepath") {
                    ForEach(ProjectStatus.allCases) { status in
                        Button(status.title, systemImage: status.symbol) { setStatus(status, for: project) }
                            .disabled(project.status == status)
                    }
                }
                Divider()
                Button("Eliminar", systemImage: "trash", role: .destructive) { pendingDelete = project }
            }
    }

    private func setStatus(_ status: ProjectStatus, for project: Project) {
        guard project.status != status else { return }
        do {
            try withAnimation(.spring(duration: 0.4)) {
                try CatalogService(context: context).setStatus(status, of: project)
            }
            toasts.show("Proyecto de \(project.displayClient): \(status.title.lowercased())")
        } catch {
            toasts.error(error)
        }
    }
}

enum ProjectEditorTarget: Identifiable {
    case new
    case edit(Project)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let project): project.objectID.uriRepresentation().absoluteString
        }
    }

    var project: Project? {
        if case .edit(let project) = self { return project }
        return nil
    }
}

/// One kanban column; accepts dropped project cards to change their status.
private struct ProjectColumn<Card: View>: View {
    var status: ProjectStatus
    var projects: [Project]
    @ViewBuilder var card: (Project) -> Card
    var onDrop: (Project) -> Void

    @Environment(\.managedObjectContext) private var context
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Pill(text: status.title, symbol: status.symbol, tint: tint)
                Text("\(projects.count)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
                Text(Fmt.money(projects.reduce(0) { $0 + $1.total }, compact: true))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 4)

            LazyVStack(spacing: 12) {
                ForEach(projects, id: \.objectID) { project in card(project) }
                if projects.isEmpty {
                    Text("Arrastra proyectos aquí")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 90)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(tint.opacity(isTargeted ? 0.16 : 0.06), in: .rect(cornerRadius: Theme.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(tint.opacity(isTargeted ? 0.6 : 0), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
        .animation(.snappy, value: isTargeted)
        .dropDestination(for: String.self) { items, _ in
            let dropped = items.compactMap(project(from:))
            dropped.forEach(onDrop)
            return !dropped.isEmpty
        } isTargeted: {
            isTargeted = $0
        }
    }

    private var tint: Color { status == .pending ? Theme.warning : status.tint }

    private func project(from uri: String) -> Project? {
        guard let url = URL(string: uri),
            let id = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
        else { return nil }
        return context.existing(Project.self, id)
    }
}

private struct ProjectCard: View {
    @ObservedObject var project: Project
    var compact: Bool
    var changeStatus: (ProjectStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if project.photoData != nil || !compact {
                Color.clear
                    .frame(height: compact ? 110 : 150)
                    .overlay { SwatchImage(data: project.photoData, name: project.fabric ?? project.displayClient, cornerRadius: 0) }
                    .clipShape(.rect(cornerRadius: Theme.smallRadius, style: .continuous))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.displayClient).font(.headline).lineLimit(1)
                    Label(Fmt.relativeDays(UrgencyPolicy.daysLeft(until: project.deliveryDate)), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                // On the board the column already shows the status, so only the switcher icon is needed.
                StatusMenu(status: project.status, iconOnly: compact, change: changeStatus)
            }

            Text(Fmt.money(project.total))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("\(Fmt.int(Int(project.quantity))) prendas × \(Fmt.money(project.price))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, -10)

            if !compact {
                HStack(spacing: 16) {
                    CardStat(symbol: "stopwatch", value: "\(Fmt.number(project.minutes)) min", label: "minutaje", tint: Theme.info)
                    CardStat(symbol: "scroll", value: project.fabric ?? "—", label: "tela", tint: Theme.thread)
                }
                if let notes = project.notes, !notes.isEmpty {
                    Text(notes).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
            } else if let fabric = project.fabric {
                Label(fabric, systemImage: "scroll").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: compact ? 14 : 18)
        .contentShape(.rect)
    }
}

/// Status pill that doubles as a quick status switcher (replaces the legacy "approve" button).
private struct StatusMenu: View {
    var status: ProjectStatus
    var iconOnly = false
    var change: (ProjectStatus) -> Void

    var body: some View {
        Menu {
            ForEach(ProjectStatus.allCases) { option in
                Button {
                    change(option)
                } label: {
                    if option == status {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            if iconOnly {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.brand)
            } else {
                HStack(spacing: 4) {
                    Pill(text: status.title, symbol: status.symbol, tint: status == .pending ? Theme.warning : status.tint)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityLabel("Estado: \(status.title). Cambiar estado")
    }
}

struct ProjectEditorSheet: View {
    var project: Project?

    @Environment(\.managedObjectContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Client.name, ascending: true)])
    private var clients: FetchedResults<Client>

    @State private var draft = ProjectDraft()
    @State private var hasDelivery = false
    @State private var delivery = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var loaded = false

    private var hasClient: Bool {
        draft.client != nil || !draft.clientName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        FormSheet(title: project == nil ? "Nuevo proyecto" : "Editar proyecto", canSave: hasClient, onSave: save) {
            Section("Cliente") {
                Picker("Cliente", selection: $draft.client) {
                    Text("Otro (escribir nombre)").tag(Client?.none)
                    ForEach(clients, id: \.objectID) { client in
                        Text(client.displayName).tag(Optional(client))
                    }
                }
                if draft.client == nil {
                    TextField("Nombre del cliente o prospecto", text: $draft.clientName)
                        .transition(.opacity)
                }
            }

            Section("Cotización") {
                IntField(title: "Cantidad (prendas)", value: $draft.quantity)
                DecimalField(title: "Precio por prenda", value: $draft.price, currency: true)
                LabeledContent("Total") {
                    Text(Fmt.money(draft.total))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.brand)
                        .contentTransition(.numericText(value: draft.total))
                        .animation(.snappy, value: draft.total)
                }
            }

            Section {
                DecimalField(title: "Minutaje (min por prenda)", value: $draft.minutes)
                TextField("Tela", text: $draft.fabric)
            } header: {
                Text("Producción")
            } footer: {
                if draft.minutes > 0, draft.quantity > 0 {
                    Text("Carga estimada: \(Fmt.number(draft.minutes * Double(draft.quantity) / 60)) horas de costura.")
                }
            }

            Section("Seguimiento") {
                Picker("Estado", selection: $draft.status) {
                    ForEach(ProjectStatus.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Fecha de entrega", isOn: $hasDelivery.animation())
                if hasDelivery {
                    DatePicker("Entrega", selection: $delivery, displayedComponents: .date)
                }
                TextField("Notas", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("Foto o muestra") {
                PhotoField(title: draft.fabric.isEmpty ? "Proyecto" : draft.fabric, data: $draft.photo)
            }
        }
        .animation(.snappy, value: draft.client)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let project {
                draft = ProjectDraft(project)
                if let date = project.deliveryDate {
                    hasDelivery = true
                    delivery = date
                }
            }
        }
    }

    private func save() {
        var draft = draft
        draft.deliveryDate = hasDelivery ? delivery : nil
        do {
            try CatalogService(context: context).saveProject(project, draft: draft)
            toasts.show(project == nil ? "Proyecto creado" : "Proyecto actualizado")
            dismiss()
        } catch {
            toasts.error(error)
        }
    }
}

#Preview("Proyectos") {
    NavigationStack { ProjectsView() }
        .catalogPreviewEnvironment()
}
