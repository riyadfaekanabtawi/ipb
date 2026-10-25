import Foundation

@testable import Trama

/// Routes URLSession requests to an in-process fake of the Trama platform API. Each fake gets
/// its own session (matched by a header), so parallel tests never share state.
final class MockURLProtocol: URLProtocol {
    static let header = "X-Mock-Platform"
    private static let lock = NSLock()
    private static var platforms: [String: FakePlatform] = [:]

    static func register(_ platform: FakePlatform) -> URLSession {
        lock.withLock { platforms[platform.key] = platform }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = [header: platform.key]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: Self.header) ?? ""
        guard let platform = Self.lock.withLock({ Self.platforms[key] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        var request = self.request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 16_384)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            request.httpBody = data
        }
        if platform.offline {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let (status, body) = platform.handle(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Minimal behavior of platform/src (auth + sync): rotating refresh tokens, cursor pagination
/// by version, last-writer-wins pushes with `stale` rejections, `forbidden` per entity, 402 when
/// the licence is not writable.
final class FakePlatform {
    struct Request {
        var method: String
        var path: String
        var query: [String: String]
        var authorization: String?
        var json: [String: Any]?
    }

    let key = UUID().uuidString
    private let lock = NSLock()
    private(set) var version: Int64 = 0
    /// Latest change per "entity/id" (id lowercased), in the server's wire shape.
    private(set) var rows: [String: [String: Any]] = [:]
    private(set) var requests: [Request] = []

    var accessToken = "access-0"
    var refreshToken = "refresh-0-0123456789abcdefghij"
    var password = "secret"
    var writable = true
    var offline = false
    var forbiddenEntities: Set<String> = []
    var tenant: [String: Any] = ["id": "6f1f7f8e-2b7c-4c1e-9d55-0c1d2e3f4a5b", "name": "Textiles Nube", "plan": "planta"]
    let userID = UUID()
    var userEmail = "admin@nube.mx"
    private var rotations = 0

    var licence: [String: Any] {
        ["plan": "planta", "status": writable ? "active" : "expired", "expiresAt": "2027-01-01T00:00:00.000Z", "writable": writable]
    }

    /// The login user, in the AppUserDTO shape the server returns (with the PBKDF2 hash).
    func userDTO() -> [String: Any] {
        let salt = PasswordHasher.makeSalt()
        return [
            "id": userID.uuidString.lowercased(), "email": userEmail, "firstName": "Ana", "lastName": "Nube", "phone": NSNull(),
            "avatarData": NSNull(), "roleRaw": Role.admin.rawValue, "isActive": true, "plantID": NSNull(),
            "passwordHash": PasswordHasher.hash(password, salt: salt), "passwordSalt": salt,
            "createdAt": iso(Date(timeIntervalSince1970: 1_700_000_000)), "updatedAt": iso(Date(timeIntervalSince1970: 1_700_000_000)),
        ]
    }

    /// Seeds a record as if another device had pushed it.
    func seed(_ entity: String, id: UUID, updatedAt: Date, data: [String: Any]?, deleted: Bool = false) {
        lock.withLock {
            version += 1
            var payload = data
            payload?["id"] = id.uuidString.lowercased()
            rows["\(entity)/\(id.uuidString.lowercased())"] = [
                "entity": entity, "id": id.uuidString.lowercased(), "updatedAt": iso(updatedAt), "deleted": deleted,
                "data": payload ?? NSNull(), "version": version,
            ]
        }
    }

    func row(_ entity: String, _ id: UUID) -> [String: Any]? { lock.withLock { rows["\(entity)/\(id.uuidString.lowercased())"] } }
    func calls(to path: String) -> [Request] { lock.withLock { requests.filter { $0.path == path } } }

    func handle(_ request: URLRequest) -> (Int, Data) {
        lock.withLock {
            let url = request.url!
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let query = Dictionary((components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
            let json = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let auth = request.value(forHTTPHeaderField: "Authorization")
            let path = url.path.replacingOccurrences(of: "/api/", with: "")
            requests.append(Request(method: request.httpMethod ?? "GET", path: path, query: query, authorization: auth, json: json))

            switch path {
            case "auth/login":
                guard (json?["email"] as? String)?.lowercased() == userEmail, json?["password"] as? String == password else {
                    return error(401, "bad_credentials", "Correo o contraseña incorrectos.")
                }
                return session()
            case "auth/refresh":
                guard json?["refreshToken"] as? String == refreshToken else {
                    return error(401, "refresh_invalid", "Tu sesión expiró. Vuelve a iniciar sesión.")
                }
                return session()
            case "auth/logout":
                guard auth == "Bearer \(accessToken)" else { return error(401, "token_invalid", "Tu sesión expiró.") }
                refreshToken = "revoked"
                return ok(["ok": true])
            case "sync/pull":
                guard auth == "Bearer \(accessToken)" else { return error(401, "token_invalid", "Tu sesión expiró.") }
                let cursor = Int64(query["cursor"] ?? "0") ?? 0
                let limit = Int(query["limit"] ?? "500") ?? 500
                let newer = rows.values.filter { ($0["version"] as! Int64) > cursor }.sorted { ($0["version"] as! Int64) < ($1["version"] as! Int64) }
                let page = Array(newer.prefix(limit))
                return ok([
                    "changes": page, "cursor": (page.last?["version"] as? Int64) ?? cursor, "hasMore": newer.count > limit, "licence": licence,
                ])
            case "sync/push":
                guard auth == "Bearer \(accessToken)" else { return error(401, "token_invalid", "Tu sesión expiró.") }
                guard writable else { return error(402, "licence_inactive", "Tu licencia venció: los datos son de solo lectura.") }
                var applied: [[String: Any]] = []
                var rejected: [[String: Any]] = []
                for change in json?["changes"] as? [[String: Any]] ?? [] {
                    let entity = change["entity"] as! String
                    // Like the real server, a non-canonical id corrupts the record (AAD mismatch).
                    guard let id = change["id"] as? String, id == id.lowercased() else {
                        return error(500, "server_error", "Ocurrió un error. Intenta de nuevo.")
                    }
                    let key = "\(entity)/\(id)"
                    if forbiddenEntities.contains(entity) {
                        rejected.append(["entity": entity, "id": id, "reason": "forbidden", "message": "Tu puesto no permite este cambio."])
                        continue
                    }
                    let incoming = parse(change["updatedAt"] as! String)
                    if let existing = rows[key], parse(existing["updatedAt"] as! String) > incoming {
                        rejected.append(["entity": entity, "id": id, "reason": "stale", "message": "Hay una versión más reciente.", "server": existing])
                        continue
                    }
                    version += 1
                    let deleted = change["deleted"] as? Bool ?? false
                    var data = change["data"] as? [String: Any]
                    data?["id"] = id
                    rows[key] = [
                        "entity": entity, "id": id, "updatedAt": change["updatedAt"]!, "deleted": deleted, "data": deleted ? NSNull() : (data ?? NSNull()),
                        "version": version,
                    ]
                    applied.append(["entity": entity, "id": id, "version": version])
                }
                return ok(["applied": applied, "rejected": rejected, "licence": licence])
            default:
                return error(404, "not_found", "Ruta no encontrada.")
            }
        }
    }

    // MARK: Helpers

    private func session() -> (Int, Data) {
        rotations += 1
        accessToken = "access-\(rotations)"
        refreshToken = "refresh-\(rotations)-0123456789abcdefghij"
        return ok([
            "accessToken": accessToken, "refreshToken": refreshToken, "expiresIn": 900, "user": userDTO(),
            "tenant": tenant.merging(["maxUsers": 10, "maxDevices": 10, "maxPlants": 1]) { a, _ in a }, "licence": licence,
        ])
    }

    private func ok(_ object: [String: Any]) -> (Int, Data) { (200, try! JSONSerialization.data(withJSONObject: object)) }

    private func error(_ status: Int, _ code: String, _ message: String) -> (Int, Data) {
        (status, try! JSONSerialization.data(withJSONObject: ["error": ["code": code, "message": message]]))
    }

    func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private func parse(_ raw: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) ?? .distantPast
    }
}
