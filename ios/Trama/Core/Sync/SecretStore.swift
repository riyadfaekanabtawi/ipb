import Foundation
import Security

/// Small key/value store for secrets (refresh token, device id). Never UserDefaults.
protocol SecretStore: AnyObject {
    func string(for key: String) -> String?
    func set(_ value: String?, for key: String)
}

/// Generic-password Keychain items, readable after first unlock and never migrated to other devices.
final class KeychainStore: SecretStore {
    private let service: String

    init(service: String = "com.nevutech.ipb.sync") { self.service = service }

    func string(for key: String) -> String? {
        var query = base(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String?, for key: String) {
        SecItemDelete(base(key) as CFDictionary)
        guard let value else { return }
        var item = base(key)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func base(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }
}

/// In-memory secrets for tests and the demo store.
final class MemorySecretStore: SecretStore {
    private var values: [String: String] = [:]
    func string(for key: String) -> String? { values[key] }
    func set(_ value: String?, for key: String) { values[key] = value }
}

/// API configuration. The base URL comes from Info.plist (`TramaAPIBaseURL`, set by the
/// `TRAMA_API_BASE_URL` build setting); DEBUG builds accept `-apiBase <url>` as a launch argument.
enum AppConfig {
    static let defaultAPIBase = URL(string: "https://trama-platform.vercel.app/api")!

    static var apiBaseURL: URL {
        #if DEBUG
            if let raw = UserDefaults.standard.string(forKey: "apiBase"), let url = URL(string: raw), url.scheme != nil {
                return url
            }
        #endif
        if let raw = Bundle.main.object(forInfoDictionaryKey: "TramaAPIBaseURL") as? String,
            !raw.isEmpty, let url = URL(string: raw), url.scheme != nil
        {
            return url
        }
        return defaultAPIBase
    }
}
