// Remote/RemoteView.swift
import SwiftUI

/// The main screen: the Titan PC's desktop, edge to edge. Status and controls
/// only appear while not connected.
struct RemoteView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: RDPSession

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                RDPView(session: session) { appState.mode = .settings }
                    .opacity(session.state == .connected ? 1 : 0.35)
                if session.reconnectAttempt > 0 {
                    // Keep the last frame visible (dimmed) while reconnecting.
                    ReconnectBanner(session: session)
                } else if session.state != .connected {
                    statusCard
                        .padding(24)
                        .frame(maxWidth: 520)
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 10) {
                    if session.state == .connected {
                        menuButton
                    }
                    ConnectionPill(heartbeat: appState.heartbeat, session: session,
                                   network: appState.network, localNetwork: appState.localNetwork,
                                   titanHost: appState.titanHost,
                                   remoteHost: appState.rdpSettings.effectiveHost(titanHost: appState.titanHost))
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
            .ignoresSafeArea()
            .onAppear {
                appState.remoteViewSize = geometry.size
                appState.autoConnectRemote()
            }
            .onChange(of: geometry.size) { _, newSize in
                appState.remoteViewSize = newSize
            }
        }
        .toolbar(session.state == .connected ? .hidden : .visible, for: .tabBar)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            switch session.state {
            case .connecting:
                ProgressView()
                    .controlSize(.large)
                Text("Connecting to \(session.host)...")
                    .font(.headline)
                Button("Cancel", role: .cancel) { session.disconnect() }
                    .buttonStyle(.glass)
            case .failed(let message):
                if appState.localNetwork.status == .denied {
                    Text(LocalNetworkHelp.message)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    Button("Open iPad Settings") { LocalNetworkHelp.openSettings() }
                        .buttonStyle(.glass)
                }
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Couldn't connect to the Titan PC")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                actionButtons
            case .idle, .connected:
                Image(systemName: "display")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(appState.isRemoteConfigured ? "Not connected" : "Remote desktop isn't set up yet")
                    .font(.headline)
                if !appState.isRemoteConfigured {
                    Text("Add the Titan PC's address and Windows login in Settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                actionButtons
            }
            DeckStatusLine(deck: appState.deck)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    /// The way out of the full-screen desktop (the tab bar is hidden while it's
    /// live). The session stays connected in the background.
    private var menuButton: some View {
        Menu {
            Button("Deck", systemImage: "square.grid.3x3.fill") { appState.mode = .deck }
            Button("Companion", systemImage: "lightbulb.2") { appState.mode = .companion }
            Button("Settings", systemImage: "gearshape") { appState.mode = .settings }
            Divider()
            Button("Send Files to PC", systemImage: "paperplane.fill") { appState.showingFileDrop = true }
            Divider()
            Button("Disconnect", systemImage: "xmark.circle", role: .destructive) { session.disconnect() }
        } label: {
            Label("Menu", systemImage: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityHint("Go to the deck or settings, or disconnect")
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if appState.isRemoteConfigured {
                Button("Connect", systemImage: "play.fill") { appState.connectRemote() }
                    .buttonStyle(.glassProminent)
            }
            Button("Settings", systemImage: "gearshape") { appState.mode = .settings }
                .buttonStyle(.glass)
        }
    }
}
