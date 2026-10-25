import Foundation

/// Legacy Rails endpoints the importer reads, in dependency order (plants before cuts, etc.).
enum LegacyResource: String, CaseIterable, Identifiable, Sendable {
    case plants, clients, suppliers, styles, users, projects, pendingCuts, cuts, reports

    var id: String { rawValue }

    var endpoint: String {
        switch self {
        case .plants: "getPlants"
        case .clients: "getClients"
        case .suppliers: "getProveedores"
        case .styles: "getStyles"
        case .users: "getUsers"
        case .projects: "getProjects"
        case .pendingCuts: "getPendingCuts"
        case .cuts: "getallcuts"
        case .reports: "getAllReports"
        }
    }

    var title: String {
        switch self {
        case .plants: String(localized: "Plantas")
        case .clients: String(localized: "Clientes")
        case .suppliers: String(localized: "Proveedores")
        case .styles: String(localized: "Estilos")
        case .users: String(localized: "Usuarios")
        case .projects: String(localized: "Proyectos")
        case .pendingCuts: String(localized: "Cortes")
        case .cuts: String(localized: "Asignaciones")
        case .reports: String(localized: "Reportes")
        }
    }

    var symbol: String {
        switch self {
        case .plants: "building.2"
        case .clients: "person.2"
        case .suppliers: "truck.box"
        case .styles: "tshirt"
        case .users: "person.badge.key"
        case .projects: "folder"
        case .pendingCuts: "scissors"
        case .cuts: "arrow.triangle.branch"
        case .reports: "doc.text"
        }
    }
}

/// Anything that can feed the importer: the real API or test fixtures.
protocol LegacySource {
    func rows(for resource: LegacyResource) async throws -> [LegacyRow]
    /// Downloads a (possibly relative) asset path such as a style photo.
    func asset(at path: String) async throws -> Data
}

enum LegacyError: LocalizedError, Equatable {
    case invalidURL
    case insecureURL
    case http(Int, String)
    case malformed(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "La dirección del servidor anterior no es válida. Usa el formato https://servidor/.")
        case .insecureURL: String(localized: "iOS bloquea conexiones sin cifrar (http). Usa la dirección https del servidor anterior.")
        case .http(let code, let endpoint): String(localized: "El servidor respondió \(code) en \(endpoint).")
        case .malformed(let endpoint): String(localized: "La respuesta de \(endpoint) no tiene el formato esperado.")
        case .offline: String(localized: "Sin conexión. Conéctate a internet para importar del sistema anterior.")
        }
    }
}

/// Minimal async client for the legacy Rails API (`{"api": [...]}` envelopes).
struct LegacyAPIClient: LegacySource {
    let baseURL: URL
    var session: URLSession = .shared

    /// Normalizes user input ("ipb.example.com" → "https://ipb.example.com/").
    init(baseString: String, session: URLSession = .shared) throws {
        var raw = baseString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw LegacyError.invalidURL }
        if !raw.contains("://") { raw = "https://" + raw }
        if !raw.hasSuffix("/") { raw += "/" }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(), url.host != nil else { throw LegacyError.invalidURL }
        guard scheme == "https" || scheme == "http" else { throw LegacyError.invalidURL }
        self.baseURL = url
        self.session = session
    }

    func rows(for resource: LegacyResource) async throws -> [LegacyRow] {
        let data = try await get(URL(string: resource.endpoint, relativeTo: baseURL)!, endpoint: resource.endpoint)
        return try Self.decodeRows(data, endpoint: resource.endpoint)
    }

    func asset(at path: String) async throws -> Data {
        guard let url = Self.assetURL(path, base: baseURL) else { throw LegacyError.invalidURL }
        return try await get(url, endpoint: path)
    }

    private func get(_ url: URL, endpoint: String) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LegacyError.http(http.statusCode, endpoint)
            }
            return data
        } catch let error as URLError {
            switch error.code {
            case .appTransportSecurityRequiresSecureConnection: throw LegacyError.insecureURL
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: throw LegacyError.offline
            default: throw error
            }
        }
    }

    /// Accepts `{"api": [...]}` (the legacy envelope) or a bare array.
    static func decodeRows(_ data: Data, endpoint: String) throws -> [LegacyRow] {
        guard let json = try? JSONDecoder().decode(LegacyJSON.self, from: data) else { throw LegacyError.malformed(endpoint) }
        let list: [LegacyJSON]
        switch json {
        case .object(let object):
            guard case .array(let array)? = object["api"] else {
                if case .null? = object["api"] { return [] }
                throw LegacyError.malformed(endpoint)
            }
            list = array
        case .array(let array): list = array
        default: throw LegacyError.malformed(endpoint)
        }
        return list.compactMap { if case .object(let row) = $0 { row } else { nil } }
    }

    /// Legacy photo fields were paths relative to the server root (Paperclip). Placeholders are skipped.
    static func assetURL(_ path: String, base: URL) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains("missing"), trimmed != "<null>" else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return URL(string: trimmed) }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }
}
