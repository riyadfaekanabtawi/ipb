import Foundation

/// Errors from the platform API. Server errors carry the server's Spanish message.
enum APIError: LocalizedError, Equatable {
    case server(status: Int, code: String, message: String)
    /// The refresh token is missing, expired or revoked: the user must connect again.
    case sessionExpired(String)
    case offline
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(_, _, let message): message
        case .sessionExpired(let message): message
        case .offline: "No hay conexión con el servidor de Trama. Revisa tu internet e intenta de nuevo."
        case .invalidResponse: "El servidor respondió algo inesperado. Intenta más tarde."
        }
    }

    var code: String? {
        switch self {
        case .server(_, let code, _): code
        case .sessionExpired: "refresh_invalid"
        case .offline: "offline"
        case .invalidResponse: nil
        }
    }
}

/// The device sent with every login: a persistent UUID kept in the Keychain.
struct DeviceInfo: Encodable, Equatable {
    var id: String
    var platform = "ios"
    var name: String
}

/// HTTP client for `/api/auth/*` and `/api/sync/*`. Keeps the access token in memory and the
/// rotating refresh token in the secret store; a 401 triggers one refresh and a retry.
@MainActor
final class APIClient {
    static let refreshTokenKey = "sync.refreshToken"

    var baseURL: URL
    private let session: URLSession
    private let secrets: SecretStore
    private(set) var accessToken: String?
    private var refreshing: Task<Void, Error>?

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared, secrets: SecretStore) {
        self.baseURL = baseURL
        self.session = session
        self.secrets = secrets
    }

    var hasRefreshToken: Bool { secrets.string(for: Self.refreshTokenKey) != nil }

    func clearTokens() {
        accessToken = nil
        secrets.set(nil, for: Self.refreshTokenKey)
    }

    // MARK: Auth

    func login(email: String, password: String, device: DeviceInfo) async throws -> AuthResponse {
        struct Body: Encodable { var email: String; var password: String; var device: DeviceInfo }
        let data = try await send(
            "auth/login", method: "POST", body: try encode(Body(email: email, password: password, device: device)), authorized: false)
        let auth = try decode(AuthResponse.self, data)
        store(auth)
        return auth
    }

    /// Rotates the refresh token. Throws `sessionExpired` when the server no longer accepts it.
    func refresh() async throws {
        if let refreshing { return try await refreshing.value }
        let task = Task { @MainActor in
            defer { self.refreshing = nil }
            guard let token = secrets.string(for: Self.refreshTokenKey) else {
                throw APIError.sessionExpired("Vuelve a conectar tu licencia para sincronizar.")
            }
            struct Body: Encodable { var refreshToken: String }
            do {
                let data = try await send("auth/refresh", method: "POST", body: try encode(Body(refreshToken: token)), authorized: false)
                store(try decode(AuthResponse.self, data))
            } catch APIError.server(let status, _, let message) where status == 401 || status == 403 {
                clearTokens()
                throw APIError.sessionExpired(message)
            }
        }
        refreshing = task
        try await task.value
    }

    /// Revokes this device's session on the server (best effort) and forgets the tokens.
    func logout() async {
        if accessToken != nil || hasRefreshToken {
            _ = try? await send("auth/logout", method: "POST", body: Data("{}".utf8), authorized: true)
        }
        clearTokens()
    }

    // MARK: Sync

    func pull(cursor: Int64, limit: Int = 500) async throws -> PullResponse {
        let data = try await send("sync/pull", query: ["cursor": String(cursor), "limit": String(limit)], authorized: true)
        return try decode(PullResponse.self, data)
    }

    /// `body` is a ready `{"changes":[…]}` document (built by the engine to control its size).
    func push(body: Data) async throws -> PushResponse {
        let data = try await send("sync/push", method: "POST", body: body, authorized: true)
        return try decode(PushResponse.self, data)
    }

    // MARK: Transport

    private func store(_ auth: AuthResponse) {
        accessToken = auth.accessToken
        secrets.set(auth.refreshToken, for: Self.refreshTokenKey)
    }

    private func send(
        _ path: String, method: String = "GET", query: [String: String] = [:], body: Data? = nil, authorized: Bool,
        retry: Bool = true
    ) async throws -> Data {
        if authorized, accessToken == nil { try await refresh() }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = components?.url else { throw APIError.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized, let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw APIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if (200..<300).contains(http.statusCode) { return data }

        if http.statusCode == 401, authorized, retry {
            accessToken = nil
            try await refresh()
            return try await send(path, method: method, query: query, body: body, authorized: true, retry: false)
        }
        struct ErrorBody: Decodable {
            struct Detail: Decodable { var code: String; var message: String }
            var error: Detail
        }
        if let detail = try? JSONDecoder().decode(ErrorBody.self, from: data).error {
            throw APIError.server(status: http.statusCode, code: detail.code, message: detail.message)
        }
        throw APIError.server(status: http.statusCode, code: "http_\(http.statusCode)", message: "El servidor no está disponible (\(http.statusCode)). Intenta más tarde.")
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data { try BackupService.encoder.encode(value) }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do {
            return try BackupService.decoder.decode(type, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }
}
