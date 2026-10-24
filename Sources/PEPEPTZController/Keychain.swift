import Foundation
import Security

/// Stores camera passwords in the macOS Keychain, one item per camera id.
enum Keychain {
    private static let service = "PEPE PTZ Controller"

    private static func baseQuery(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
        ]
    }

    static func password(for id: UUID) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the password, replacing any old one. An empty password removes it.
    @discardableResult
    static func setPassword(_ password: String, for id: UUID) -> Bool {
        deletePassword(for: id)
        guard !password.isEmpty else { return true }
        var query = baseQuery(for: id)
        query[kSecValueData as String] = Data(password.utf8)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func deletePassword(for id: UUID) {
        SecItemDelete(baseQuery(for: id) as CFDictionary)
    }
}
