// Support/NetworkMonitor.swift
import Foundation
import Network

/// Watches the iPad's network path. On set the iPad should be on Ethernet
/// (the AirWire into the USB-C hub), so the pill shows which interface is live.
@MainActor
final class NetworkMonitor: ObservableObject {
    enum Interface: String {
        case ethernet = "Ethernet"
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case other = "Network"
        case none = "No network"
    }

    @Published private(set) var interface: Interface = .none
    @Published private(set) var isSatisfied = false
    /// BSD name of the interface in use ("en0"), for reading its address.
    @Published private(set) var interfaceName: String?

    private let monitor = NWPathMonitor()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            let interface: Interface
            if !satisfied {
                interface = .none
            } else if path.usesInterfaceType(.wiredEthernet) {
                interface = .ethernet
            } else if path.usesInterfaceType(.wifi) {
                interface = .wifi
            } else if path.usesInterfaceType(.cellular) {
                interface = .cellular
            } else {
                interface = .other
            }
            let name: String?
            switch interface {
            case .ethernet: name = path.availableInterfaces.first { $0.type == .wiredEthernet }?.name
            case .wifi: name = path.availableInterfaces.first { $0.type == .wifi }?.name
            case .cellular: name = path.availableInterfaces.first { $0.type == .cellular }?.name
            case .other: name = path.availableInterfaces.first?.name
            case .none: name = nil
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.interface != interface || self.isSatisfied != satisfied {
                        Log.deck("Network path: \(interface.rawValue)")
                    }
                    self.interface = interface
                    self.isSatisfied = satisfied
                    self.interfaceName = name
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "TitanDeck.NetworkMonitor"))
    }
}
