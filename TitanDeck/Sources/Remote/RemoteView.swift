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
                if session.state != .connected {
                    statusCard
                        .padding(24)
                        .frame(maxWidth: 520)
                }
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
