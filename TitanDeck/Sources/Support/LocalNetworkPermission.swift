// Support/LocalNetworkPermission.swift
import Foundation
import Network

/// iOS blocks LAN traffic until the user allows "Local Network" for the app,
/// and a denial looks just like the Titan PC being off. There's no direct API
/// to ask, so this browses for a Bonjour service (declared in Info.plist): the
/// browser reports a policy-denied error when the permission is off. Starting
/// it also makes iOS show the permission prompt on first launch.
@MainActor
final class LocalNetworkPermission: ObservableObject {
    enum Status {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var status: Status = .unknown

    static let bonjourType = "_titandeck._tcp"
    /// kDNSServiceErr_PolicyDenied from dns_sd.h.
    private static let policyDenied: Int32 = -65570

    private var browser: NWBrowser?

    func check() {
        browser?.cancel()
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjour(type: Self.bonjourType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            let result: Status?
            switch state {
            case .ready:
                result = .granted
            case .waiting(let error), .failed(let error):
                if case .dns(let code) = error, code == Self.policyDenied {
                    result = .denied
                } else {
                    result = nil
                }
            default:
                result = nil
            }
            guard let result else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.status != result else { return }
                    self.status = result
                    Log.deck("Local Network permission: \(result)")
                }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }
}
