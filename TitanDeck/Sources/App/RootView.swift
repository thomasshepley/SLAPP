// App/RootView.swift
import SwiftUI
import UIKit

/// Remote view full screen by default on iPad; Settings is one tab away, or
/// opened by a deck key with the openSettings action. On iPhone the Remote tab
/// is off until turned on in Settings, and the app opens on the Companion.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // A device default, not a layout decision: iPhone Duo open is regular
    // width but is still a phone, where remote desktop is opt-in.
    @AppStorage(SettingsKeys.remoteDesktopEnabled)
    private var remoteDesktopEnabled = UIDevice.current.userInterfaceIdiom != .phone
    /// The version whose What's New was last shown, so it pops up once per update.
    @AppStorage("whatsNew.lastShownVersion") private var lastShownVersion = ""
    @State private var whatsNewVersion: String?

    var body: some View {
        TabView(selection: $appState.mode) {
            if remoteDesktopEnabled {
                RemoteView(session: appState.rdp)
                    .tabItem { Label("Remote", systemImage: "display") }
                    .tag(AppState.Mode.remote)
            }

            OnScreenDeckView(deck: appState.deck)
                .tabItem { Label("Deck", systemImage: "square.grid.3x3.fill") }
                .tag(AppState.Mode.deck)

            CompanionView()
                .tabItem { Label("Companion", systemImage: "lightbulb.2") }
                .tag(AppState.Mode.companion)

            UniFiView(store: appState.unifi)
                .tabItem { Label("Wi-Fi", systemImage: "wifi.router") }
                .tag(AppState.Mode.network)

            SlateBookView(store: appState.slates)
                .tabItem { Label("Slates", systemImage: "film.stack") }
                .tag(AppState.Mode.slates)

            FXTabView()
                .tabItem { Label("FX", systemImage: "sparkles") }
                .tag(AppState.Mode.fx)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppState.Mode.settings)
        }
        .onAppear(perform: pickStartingTab)
        // What's New waits until the loading screen is done with.
        .onChange(of: appState.showingStartup) { _, showing in if !showing { showWhatsNewAfterUpdate() } }
        .sheet(item: Binding(get: { whatsNewVersion.map(VersionID.init) }, set: { whatsNewVersion = $0?.id })) { version in
            WhatsNewView(onlyVersion: version.id)
        }
        .sheet(isPresented: $appState.showingFileDrop) {
            FileDropView(store: appState.fileDrop, hostStore: appState.host, host: appState.pcHost)
        }
        .onChange(of: remoteDesktopEnabled) { _, enabled in
            if !enabled {
                appState.rdp.disconnect()
                if appState.mode == .remote { appState.mode = .settings }
            }
        }
        .alert("TitanDeck was in the background",
               isPresented: Binding(get: { appState.wasBackgrounded }, set: { if !$0 { appState.dismissBackgroundWarning() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Stream Deck keys only work while TitanDeck is on screen. Check the deck is responding before carrying on.")
        }
    }

    private func showWhatsNewAfterUpdate() {
        let current = Bundle.main.shortVersion
        guard current != lastShownVersion else { return }
        lastShownVersion = current
        if Changelog.bundled().entry(for: current) != nil {
            whatsNewVersion = current
        }
    }

    private struct VersionID: Identifiable {
        let id: String
    }

    private func pickStartingTab() {
        guard appState.mode == .remote else { return }
        if !remoteDesktopEnabled {
            appState.mode = .companion
        } else if horizontalSizeClass == .compact {
            // On a phone-sized screen the deck matters more than the desktop.
            appState.mode = .deck
        }
    }
}

/// One-line deck status: which device is attached and which page is showing.
struct DeckStatusLine: View {
    @ObservedObject var deck: DeckSessionController

    var body: some View {
        Group {
            if let device = deck.device {
                let page = deck.currentPage?.name ?? "-"
                Text("\(device.info.productName) - page \(deck.currentPageIndex + 1): \(page)")
            } else {
                Text("No Stream Deck attached - \(deck.statusText)")
            }
        }
        .font(.callout.monospaced())
        .foregroundStyle(.secondary)
    }
}
