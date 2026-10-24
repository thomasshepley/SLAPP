// Support/WiFiDetails.swift
import CoreLocation
import NetworkExtension

/// Which Wi-Fi network and access point the device is on.
///
/// iOS only hands this to apps with the Access Wi-Fi Information entitlement
/// AND precise Location permission (network names can reveal where you are),
/// so the permission is asked for only when the details panel is opened.
/// Signal strength isn't available to apps at all on iOS.
@MainActor
final class WiFiDetails: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    struct Network: Equatable {
        let ssid: String
        /// The access point's MAC address. Changes when the device roams.
        let bssid: String
        let security: String
    }

    enum Access: Equatable {
        /// Location hasn't been asked for yet.
        case notAsked
        /// Location is allowed, precisely.
        case allowed
        /// Allowed, but only approximately - iOS then withholds Wi-Fi details.
        case approximate
        /// Refused or restricted - fixable in Settings.
        case denied
    }

    @Published private(set) var network: Network?
    @Published private(set) var access: Access = .notAsked
    /// Access points seen since the panel opened, newest last, to spot roaming.
    @Published private(set) var accessPointsSeen: [String] = []

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        access = Self.access(for: manager)
    }

    func requestAccess() {
        manager.requestWhenInUseAuthorization()
    }

    func refresh() {
        guard access == .allowed else {
            network = nil
            return
        }
        NEHotspotNetwork.fetchCurrent { [weak self] current in
            let network = current.map {
                Network(ssid: $0.ssid, bssid: $0.bssid.uppercased(), security: Self.describe($0.securityType))
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.network = network
                    if let bssid = network?.bssid, self.accessPointsSeen.last != bssid {
                        self.accessPointsSeen.append(bssid)
                    }
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        access = Self.access(for: manager)
        refresh()
    }

    private static func access(for manager: CLLocationManager) -> Access {
        switch manager.authorizationStatus {
        case .notDetermined: return .notAsked
        case .denied, .restricted: return .denied
        default: return manager.accuracyAuthorization == .fullAccuracy ? .allowed : .approximate
        }
    }

    nonisolated private static func describe(_ type: NEHotspotNetworkSecurityType) -> String {
        switch type {
        case .open: return "Open"
        case .WEP: return "WEP"
        case .personal: return "WPA Personal"
        case .enterprise: return "WPA Enterprise"
        default: return "Unknown"
        }
    }
}
