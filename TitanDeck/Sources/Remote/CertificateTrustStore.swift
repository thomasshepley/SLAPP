// Remote/CertificateTrustStore.swift
import Foundation

/// Trust-on-first-use for the Titan PC's RDP certificate. Windows uses a
/// self-signed certificate, so there's no authority to check against. The
/// first fingerprint seen for a host is remembered, and a different one later
/// is refused until it's forgotten in Settings. That stops a stranger's
/// machine on the show network posing as the Titan PC.
///
/// Called from the RDP connection thread; UserDefaults is thread-safe.
struct CertificateTrustStore {
    enum Decision: Equatable {
        /// Never seen this host before: remembered and accepted.
        case trustedFirstUse
        /// Matches the remembered fingerprint.
        case trusted
        /// Differs from the remembered fingerprint: refuse.
        case mismatch
    }

    let defaults: UserDefaults
    static let key = "rdpTrustedCertificates"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func evaluate(host: String, port: UInt16, fingerprint: String) -> Decision {
        let id = Self.identifier(host: host, port: port)
        var trusted = defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
        let normalised = fingerprint.lowercased()
        if let stored = trusted[id] {
            return stored == normalised ? .trusted : .mismatch
        }
        guard !normalised.isEmpty else { return .mismatch }
        trusted[id] = normalised
        defaults.set(trusted, forKey: Self.key)
        return .trustedFirstUse
    }

    func forgetAll() {
        defaults.removeObject(forKey: Self.key)
    }

    var trustedHosts: [String] {
        (defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]).keys.sorted()
    }

    static func identifier(host: String, port: UInt16) -> String {
        "\(host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()):\(port)"
    }
}
