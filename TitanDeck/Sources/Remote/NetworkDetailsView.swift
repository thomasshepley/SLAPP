// Remote/NetworkDetailsView.swift
import SwiftUI

/// Opened by tapping the network part of the connection pill: which network
/// the iPad is on, its address, whether the Titan PC is on the same network,
/// and how steady the link to Titan is.
struct NetworkDetailsView: View {
    @ObservedObject var network: NetworkMonitor
    @ObservedObject var heartbeat: TitanHeartbeat
    @ObservedObject var session: RDPSession
    let titanHost: String
    let remoteHost: String

    @StateObject private var wifi = WiFiDetails()
    @State private var address: IPv4Interface?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                if network.interface == .wifi {
                    wifiSection
                }
                titanSection
                remoteSection
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .task {
            // Cheap to read, so keep it live while the panel is open.
            while !Task.isCancelled {
                address = network.interfaceName.flatMap(InterfaceAddress.ipv4)
                wifi.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: - Sections

    private var connectionSection: some View {
        Section {
            LabeledContent("Using") {
                Label(network.interface.rawValue, systemImage: interfaceSymbol)
                    .foregroundStyle(network.isSatisfied ? Color.primary : Color.red)
            }
            LabeledContent("iPad address", value: address?.address ?? "-")
                .monospacedDigit()
            if let netmask = address?.netmask, !netmask.isEmpty {
                LabeledContent("Subnet mask", value: netmask)
                    .monospacedDigit()
            }
        } header: {
            Text("This iPad")
        } footer: {
            if network.interface == .wifi {
                Text("On set, use the AirWire into the USB-C hub and turn Wi-Fi off.")
            }
        }
    }

    @ViewBuilder
    private var wifiSection: some View {
        Section {
            switch wifi.access {
            case .allowed:
                LabeledContent("Network", value: wifi.network?.ssid ?? "Reading...")
                LabeledContent("Access point") {
                    Text(wifi.network?.bssid ?? "-")
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                LabeledContent("Security", value: wifi.network?.security ?? "-")
                if wifi.accessPointsSeen.count > 1 {
                    LabeledContent("Roamed", value: "\(wifi.accessPointsSeen.count - 1)x since opening")
                        .foregroundStyle(.orange)
                }
            case .notAsked:
                Text("iOS only shows the Wi-Fi network name and access point to apps allowed to use Location. TitanDeck never records where you are.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Allow Location", systemImage: "location") { wifi.requestAccess() }
            case .approximate:
                Text("Location is set to approximate. Turn on Precise Location for TitanDeck to see the network and access point.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Open Settings", systemImage: "gearshape") { LocalNetworkHelp.openSettings() }
            case .denied:
                Text("Location is off for TitanDeck, so iOS hides the Wi-Fi name and access point.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Open Settings", systemImage: "gearshape") { LocalNetworkHelp.openSettings() }
            }
        } header: {
            Text("Wi-Fi")
        } footer: {
            Text("iOS doesn't let apps read signal strength (iPad Settings > Wi-Fi shows the bars). The reply times below are the next best measure: low and steady is good.")
        }
    }

    private var titanSection: some View {
        let summary = LatencySummary(samples: heartbeat.recentSamples)
        return Section {
            LabeledContent("Address", value: titanHost.isEmpty ? "Not set" : titanHost)
                .monospacedDigit()
            if let same = sameNetwork(as: titanHost) {
                sameNetworkRow(same, host: titanHost)
            }
            LabeledContent("Reply time") {
                Text(replyText)
                    .foregroundStyle(replyColor)
            }
            .monospacedDigit()
            if summary.replies + summary.misses > 1 {
                LabeledContent("Last minute") {
                    Text(minuteText(summary))
                }
                .monospacedDigit()
                LabeledContent("Missed replies") {
                    Text("\(summary.misses) of \(summary.replies + summary.misses) (\(summary.lossPercent)%)")
                        .foregroundStyle(summary.misses == 0 ? Color.secondary : Color.orange)
                }
                .monospacedDigit()
            }
        } header: {
            Text("Titan PC")
        } footer: {
            Text("Checked every 2 seconds. Keys give up after 500 ms, so steady replies well under 100 ms are what you want.")
        }
    }

    private var remoteSection: some View {
        Section("Remote desktop") {
            LabeledContent("Address", value: remoteHost.isEmpty ? "Not set" : remoteHost)
                .monospacedDigit()
            if remoteHost != titanHost, let same = sameNetwork(as: remoteHost) {
                sameNetworkRow(same, host: remoteHost)
            }
            LabeledContent("State", value: remoteState)
        }
    }

    // MARK: - Helpers

    private func sameNetwork(as host: String) -> Bool? {
        guard let address, !address.netmask.isEmpty else { return nil }
        return InterfaceAddress.sameSubnet(address: address.address, netmask: address.netmask, as: host)
    }

    @ViewBuilder
    private func sameNetworkRow(_ same: Bool, host: String) -> some View {
        if same {
            Label("Same network as this iPad", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("Not on this iPad's network (\(address?.address ?? "?") / \(address?.netmask ?? "?")), so it can't be reached directly.",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func minuteText(_ summary: LatencySummary) -> String {
        guard let average = summary.average, let fastest = summary.fastest, let slowest = summary.slowest else {
            return "No replies"
        }
        let jitter = summary.jitter.map { ", jitter \($0) ms" } ?? ""
        return "avg \(average) ms (\(fastest)-\(slowest))\(jitter)"
    }

    private var replyText: String {
        switch heartbeat.health {
        case .ok(let ms), .slow(let ms): return "\(ms) ms"
        case .down: return "No reply"
        case .unknown: return titanHost.isEmpty ? "-" : "Waiting..."
        }
    }

    private var replyColor: Color {
        switch heartbeat.health {
        case .ok: return .green
        case .slow: return .yellow
        case .down: return .red
        case .unknown: return .secondary
        }
    }

    private var remoteState: String {
        if session.reconnectAttempt > 0 { return "Reconnecting (attempt \(session.reconnectAttempt))" }
        switch session.state {
        case .connected: return "Live"
        case .connecting: return "Connecting"
        case .failed(let message): return "Down - \(message)"
        case .idle: return "Off"
        }
    }

    private var interfaceSymbol: String {
        switch network.interface {
        case .ethernet: return "cable.connector"
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .other: return "network"
        case .none: return "wifi.slash"
        }
    }
}
