// Remote/RDPSettings.swift
import Foundation

/// Where and how to log in to the Titan PC's remote desktop. The password is
/// never stored here: it lives in the Keychain (see `keychainAccount`).
struct RDPSettings: Codable, Hashable {
    /// PC address. Empty means "same as the Titan WebAPI host".
    var host: String = ""
    var port: UInt16 = 3389
    var username: String = ""
    var domain: String = ""
    /// Connect automatically when the app opens.
    var autoConnect = true

    /// The address to actually use, falling back to the Titan host.
    func effectiveHost(titanHost: String) -> String {
        let own = host.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? titanHost.trimmingCharacters(in: .whitespacesAndNewlines) : own
    }

    func isComplete(titanHost: String) -> Bool {
        !effectiveHost(titanHost: titanHost).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Keychain account the password is saved under.
    var keychainAccount: String {
        "\(username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())@rdp"
    }

    static let defaultsKey = "rdpSettings"

    static func load(from defaults: UserDefaults = .standard) -> RDPSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(RDPSettings.self, from: data) else { return RDPSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
