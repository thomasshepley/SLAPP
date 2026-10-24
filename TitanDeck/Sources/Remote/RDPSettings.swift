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
    /// Connect automatically when the app opens. Off by default: the app opens
    /// on the remote view and waits for Connect.
    var connectOnLaunch = false
    /// Picture quality: visual effects here, image quality and frame rate on the PC.
    var quality = RDPQuality.preset(.best)

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

    init() {}

    // Decoded by hand so settings saved by older builds still load. Their
    // `autoConnect` key (on by default back then) is deliberately ignored, which
    // turns connect-on-launch off once.
    private enum CodingKeys: String, CodingKey {
        case host, port, username, domain, connectOnLaunch, quality
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try container.decodeIfPresent(UInt16.self, forKey: .port) ?? 3389
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        domain = try container.decodeIfPresent(String.self, forKey: .domain) ?? ""
        connectOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .connectOnLaunch) ?? false
        quality = (try? container.decodeIfPresent(RDPQuality.self, forKey: .quality)) ?? RDPQuality.preset(.best)
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
