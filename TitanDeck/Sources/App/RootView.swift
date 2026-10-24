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

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppState.Mode.settings)
        }
        .onAppear(perform: pickStartingTab)
        .sheet(isPresented: $appState.showingFileDrop) {
            FileDropView(store: appState.fileDrop, host: appState.pcHost)
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
