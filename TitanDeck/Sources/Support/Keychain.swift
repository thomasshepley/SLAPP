// Support/Keychain.swift
import Foundation
import Security

/// Minimal Keychain wrapper for the RDP password. Items are only readable
/// while the device is unlocked, and never sync to iCloud.
enum Keychain {
    static let service = "uk.co.elexproductions.titandeck"

    static func password(for account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the password, or deletes it when nil or empty.
    @discardableResult
    static func setPassword(_ password: String?, for account: String) -> Bool {
        SecItemDelete(baseQuery(account) as CFDictionary)
        guard let password, !password.isEmpty else { return true }
        var item = baseQuery(account)
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
