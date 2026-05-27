import Foundation
import Security

enum AIConfig {
    private static let keychainKey = "com.ambidash.anthropic-api-key"

    static var apiKey: String {
        readKeychain(key: keychainKey) ?? ""
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty
    }

    static func setApiKey(_ key: String) {
        if key.isEmpty {
            deleteKeychain(key: keychainKey)
        } else {
            saveKeychain(key: keychainKey, value: key)
        }
    }

    static let model = "claude-sonnet-4-20250514"
    static let maxTokens = 1024

    // MARK: - Keychain helpers

    private static func saveKeychain(key: String, value: String) {
        deleteKeychain(key: key)
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func readKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
