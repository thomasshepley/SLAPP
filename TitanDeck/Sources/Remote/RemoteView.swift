// Remote/RemoteView.swift
import SwiftUI

/// The main screen: the Titan PC's desktop, edge to edge. Status and controls
/// only appear while not connected. The keypad readout sits in the black band
/// under the desktop when the PC's screen shape leaves one.
struct RemoteView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: RDPSession
    /// The iPad's on-screen keyboard, typing on the PC.
    @State private var softKeyboardShown = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                RDPView(session: session, commandKey: appState.rdpSettings.commandKey,
                        softKeyboardShown: $softKeyboardShown) { appState.mode = .settings }
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
            .overlay {
                if session.state == .connected {
                    KeypadReadoutLayer(store: appState.keypad, deck: appState.deck,
                                       desktopSize: session.desktopSize)
                        .allowsHitTesting(false)   // display only; touches go to the desktop
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 8) {
                    ModeBadge()
                    SelectedFixtureChip(deck: appState.deck)
                }
                .padding(.top, 12)
                .padding(.leading, 16)
                .allowsHitTesting(false)   // touches go through to the desktop
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 10) {
                    if session.state == .connected {
                        keyboardButton
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
            .onChange(of: session.state) { _, state in
                if state != .connected { softKeyboardShown = false }
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

    /// Shows and hides the iPad's on-screen keyboard; it types on the PC.
    private var keyboardButton: some View {
        Button {
            softKeyboardShown.toggle()
        } label: {
            Image(systemName: softKeyboardShown ? "keyboard.chevron.compact.down" : "keyboard")
                .font(.caption.weight(.semibold))
                .frame(width: 18, height: 18)
                .padding(8)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .glassEffect(softKeyboardShown ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(softKeyboardShown ? "Hide keyboard" : "Show keyboard")
        .accessibilityHint("The on-screen keyboard types on the PC")
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
            Menu {
                ForEach(RDPQuality.Preset.allCases) { preset in
                    Button {
                        Task { await appState.applyRemoteQuality(.preset(preset)) }
                    } label: {
                        if appState.rdpSettings.quality.preset == preset {
                            Label(preset.title, systemImage: "checkmark")
                        } else {
                            Text(preset.title)
                        }
                    }
                }
            } label: {
                Label("Picture: \(appState.rdpSettings.quality.preset?.title ?? "Custom")", systemImage: "dial.medium")
            }
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

/// "Currently Selected: 101" in the top left: the fixture the deck's keypad
/// left in Titan's programmer. Gone after a Clear empties the programmer.
private struct SelectedFixtureChip: View {
    @ObservedObject var deck: DeckSessionController

    var body: some View {
        if let fixture = deck.selectionLabel {
            // Same look as the Menu button and the connection pill opposite.
            HStack(spacing: 5) {
                Image(systemName: "scope")
                    .foregroundStyle(.secondary)
                Text("Currently Selected:")
                    .foregroundStyle(.secondary)
                Text(fixture)
                    .contentTransition(.numericText())
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .animation(.snappy, value: fixture)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Places the keypad readout: in the band under the letterboxed desktop if
/// there's room, otherwise as a small floating capsule while typing.
private struct KeypadReadoutLayer: View {
    @ObservedObject var store: KeypadReadoutStore
    @ObservedObject var deck: DeckSessionController
    let desktopSize: CGSize

    /// Shorter than this and the band can't hold the readout.
    private static let minimumBand: CGFloat = 40

    private var onKeypad: Bool {
        deck.currentPage?.keys.contains { $0.action.map(KeypadReadout.isKeypad) ?? false } ?? false
    }
    private var isTyping: Bool { store.readout.current != nil || store.flashingID != nil }

    var body: some View {
        GeometryReader { geometry in
            let desktop = DesktopMapper(viewSize: geometry.size, desktopSize: desktopSize).fittedRect
            let band = desktop.height > 0 ? geometry.size.height - desktop.maxY : 0
            if band >= Self.minimumBand {
                if onKeypad || isTyping || !store.readout.history.isEmpty {
                    KeypadReadoutBar(store: store, height: band)
                        .frame(width: geometry.size.width)
                        .position(x: geometry.size.width / 2, y: desktop.maxY + band / 2)
                        .transition(.opacity)
                }
            } else if isTyping {
                KeypadReadoutBar(store: store, height: 56)
                    .frame(maxWidth: min(geometry.size.width - 32, 720))
                    .background(.black.opacity(0.75), in: .capsule)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 44)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: onKeypad)
    }
}
