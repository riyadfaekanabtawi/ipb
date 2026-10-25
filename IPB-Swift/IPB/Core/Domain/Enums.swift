import SwiftUI

/// Job title ("puesto") of an IPB user. Drives navigation and report permissions.
/// Raw values match the legacy backend strings so imported data maps 1:1.
enum Role: String, CaseIterable, Identifiable, Codable {
    case admin = "Administrador"
    case plantManager = "Gerente de Planta"
    case cutManager = "Gerente de Cortes"
    case shippingManager = "Gerente de Envios"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .admin: "Administrador"
        case .plantManager: "Gerente de planta"
        case .cutManager: "Gerente de cortes"
        case .shippingManager: "Gerente de envíos"
        }
    }

    var symbol: String {
        switch self {
        case .admin: "crown.fill"
        case .plantManager: "building.2.fill"
        case .cutManager: "scissors"
        case .shippingManager: "shippingbox.fill"
        }
    }

    /// Report kinds this role may create. Admin chooses among all.
    var creatableReports: [ReportKind] {
        switch self {
        case .admin: ReportKind.allCases
        case .plantManager: [.plant]
        case .cutManager: [.cut]
        case .shippingManager: [.shipment]
        }
    }

    func canEdit(_ kind: ReportKind) -> Bool { creatableReports.contains(kind) }

    /// Sections visible in the sidebar, mirroring the legacy menu gating.
    var sections: [AppSection] {
        switch self {
        case .admin: AppSection.allCases
        case .cutManager: [.orders, .board, .production, .calendar, .settings]
        case .plantManager: [.production, .settings]
        case .shippingManager: [.production, .shipments, .settings]
        }
    }

    var landing: AppSection {
        switch self {
        case .admin: .dashboard
        case .cutManager: .orders
        case .plantManager, .shippingManager: .production
        }
    }
}

/// Cutting-table status of an assignment, set through the cut report.
enum CutStatus: String, CaseIterable, Identifiable, Codable {
    case waiting = "en_espera"
    case onTable = "en_mesa_de_corte"
    case ready = "listo_para_confeccionar"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waiting: "En espera"
        case .onTable: "En mesa de corte"
        case .ready: "Listo para confeccionar"
        }
    }

    var symbol: String {
        switch self {
        case .waiting: "hourglass"
        case .onTable: "scissors"
        case .ready: "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .waiting: Theme.danger
        case .onTable: Theme.warning
        case .ready: Theme.success
        }
    }

    /// Accepts both new raw values and the legacy free-text statuses.
    init(legacy value: String?) {
        let normalized = (value ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        switch normalized {
        case "en mesa de corte", Self.onTable.rawValue: self = .onTable
        case "listo para confeccionar", Self.ready.rawValue: self = .ready
        default: self = .waiting
        }
    }
}

enum ReportKind: String, CaseIterable, Identifiable, Codable {
    case plant = "planta"
    case cut = "corte"
    case shipment = "envio"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plant: "Reporte de planta"
        case .cut: "Reporte de corte"
        case .shipment: "Reporte de envío"
        }
    }

    var shortTitle: String {
        switch self {
        case .plant: "Planta"
        case .cut: "Corte"
        case .shipment: "Envío"
        }
    }

    var symbol: String {
        switch self {
        case .plant: "building.2"
        case .cut: "scissors"
        case .shipment: "shippingbox"
        }
    }

    var tint: Color {
        switch self {
        case .plant: Theme.brand
        case .cut: Theme.warning
        case .shipment: Theme.info
        }
    }
}

enum ProjectStatus: String, CaseIterable, Identifiable, Codable {
    case pending = "pendiente"
    case accepted = "aceptado"
    case declined = "declinado"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Pendiente"
        case .accepted: "Aceptado"
        case .declined: "Declinado"
        }
    }

    var tint: Color {
        switch self {
        case .pending: .secondary
        case .accepted: Theme.success
        case .declined: Theme.danger
        }
    }

    var symbol: String {
        switch self {
        case .pending: "clock"
        case .accepted: "checkmark.circle.fill"
        case .declined: "xmark.circle.fill"
        }
    }
}

/// Assignment state of a cut order, derived from how much of it has been sent to plants.
enum OrderAssignmentState: String, CaseIterable, Identifiable {
    case unassigned, partial, assigned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unassigned: "Por asignar"
        case .partial: "Parcial"
        case .assigned: "Asignado"
        }
    }

    var tint: Color {
        switch self {
        case .unassigned: Theme.danger
        case .partial: Theme.warning
        case .assigned: Theme.success
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard, orders, board, production, shipments, calendar
    case plants, clients, suppliers, styles, projects, users
    case calculator, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .orders: "Cortes por asignar"
        case .board: "Tablero de corte"
        case .production: "Reportes de producción"
        case .shipments: "Envíos urgentes"
        case .calendar: "Calendario de plantas"
        case .plants: "Plantas"
        case .clients: "Clientes"
        case .suppliers: "Proveedores"
        case .styles: "Estilos"
        case .projects: "Proyectos"
        case .users: "Usuarios"
        case .calculator: "Calculadora"
        case .settings: "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2.fill"
        case .orders: "scissors"
        case .board: "rectangle.split.3x1.fill"
        case .production: "chart.bar.doc.horizontal.fill"
        case .shipments: "exclamationmark.triangle.fill"
        case .calendar: "calendar"
        case .plants: "building.2.fill"
        case .clients: "person.2.fill"
        case .suppliers: "truck.box.fill"
        case .styles: "tshirt.fill"
        case .projects: "folder.fill"
        case .users: "person.badge.key.fill"
        case .calculator: "function"
        case .settings: "gearshape.fill"
        }
    }

    var group: Group {
        switch self {
        case .dashboard, .orders, .board, .production, .shipments, .calendar: .operations
        case .plants, .clients, .suppliers, .styles, .projects, .users: .catalogs
        case .calculator, .settings: .tools
        }
    }

    enum Group: String, CaseIterable {
        case operations = "Operación"
        case catalogs = "Catálogos"
        case tools = "Herramientas"
    }
}
