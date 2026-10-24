// Remote/ConnectionPill.swift
import SwiftUI
import UIKit

/// Always-visible status in the corner of the remote view: Titan WebAPI,
/// remote desktop and network. Tap the network part for connection details;
/// tap the rest to shrink it to dots.
struct ConnectionPill: View {
    @ObservedObject var heartbeat: TitanHeartbeat
    @ObservedObject var session: RDPSession
    @ObservedObject var network: NetworkMonitor
    @ObservedObject var localNetwork: LocalNetworkPermission
    let titanHost: String
    let remoteHost: String
    @AppStorage("connectionPillCompact") private var compact = false
    @State private var showingDetails = false

    var body: some View {
        HStack(spacing: compact ? 6 : 14) {
            Button {
                withAnimation(.snappy) { compact.toggle() }
            } label: {
                HStack(spacing: compact ? 6 : 14) {
                    if localNetwork.status == .denied {
                        item(color: .orange, symbol: "exclamationmark.triangle.fill", text: "Local Network off")
                    }
                    item(color: titanColor, symbol: "slider.horizontal.3", text: titanText)
                    item(color: rdpColor, symbol: "display", text: rdpText)
                }
                .contentShape(.rect)
            }
            .accessibilityLabel("Connection status: Titan \(titanText), remote desktop \(rdpText)")
            .accessibilityHint(compact ? "Shows the full status" : "Shrinks the status to dots")

            Button {
                showingDetails = true
            } label: {
                item(color: network.isSatisfied ? .green : .red, symbol: networkSymbol, text: network.interface.rawValue)
                    .contentShape(.rect)
            }
            .accessibilityLabel("\(network.interface.rawValue) details")
            .popover(isPresented: $showingDetails, arrowEdge: .top) {
                NetworkDetailsView(network: network, heartbeat: heartbeat, session: session,
                                   titanHost: titanHost, remoteHost: remoteHost)
                    .frame(minWidth: 380, idealWidth: 420, minHeight: 560, idealHeight: 640)
                    .presentationCompactAdaptation(.sheet)
            }
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold).monospacedDigit())
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    @ViewBuilder
    private func item(color: Color, symbol: String, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            if !compact {
                Image(systemName: symbol).foregroundStyle(.secondary)
                Text(text)
            }
        }
    }

    // MARK: - Titan

    private var titanColor: Color {
        switch heartbeat.health {
        case .ok: return .green
        case .slow: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }

    private var titanText: String {
        switch heartbeat.health {
        case .ok(let ms), .slow(let ms): return "\(ms) ms"
        case .down: return "No reply"
        case .unknown: return "Not set"
        }
    }

    // MARK: - RDP

    private var rdpColor: Color {
        switch session.state {
        case .connected: return .green
        case .connecting: return .yellow
        case .failed: return session.reconnectAttempt > 0 ? .yellow : .red
        case .idle: return .gray
        }
    }

    private var rdpText: String {
        if session.reconnectAttempt > 0 { return "Retry \(session.reconnectAttempt)" }
        switch session.state {
        case .connected: return "Live"
        case .connecting: return "Connecting"
        case .failed: return "Down"
        case .idle: return "Off"
        }
    }

    private var networkSymbol: String {
        switch network.interface {
        case .ethernet: return "cable.connector"
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .other: return "network"
        case .none: return "wifi.slash"
        }
    }
}

/// Shown over the dimmed last frame while a dropped session reconnects.
struct ReconnectBanner: View {
    @ObservedObject var session: RDPSession

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text("Reconnecting to \(session.host)")
                    .font(.headline)
                if let next = session.nextReconnect {
                    Text("Attempt \(session.reconnectAttempt) - next try \(next, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Attempt \(session.reconnectAttempt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Stop", role: .cancel) { session.disconnect() }
                .buttonStyle(.glass)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .capsule)
    }
}

/// How to fix a denied Local Network permission.
enum LocalNetworkHelp {
    static let message = "TitanDeck can't reach the show network. Turn on Settings > Privacy & Security > Local Network > TitanDeck."

    @MainActor
    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
