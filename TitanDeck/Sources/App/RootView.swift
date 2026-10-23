// App/RootView.swift
import SwiftUI

/// Remote view full screen by default; Settings is one tab away, or opened by
/// a deck key with the openSettings action.
struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        TabView(selection: $appState.mode) {
            RemoteView(session: appState.rdp)
                .tabItem { Label("Remote", systemImage: "display") }
                .tag(AppState.Mode.remote)

            OnScreenDeckView(deck: appState.deck)
                .tabItem { Label("Deck", systemImage: "square.grid.3x3.fill") }
                .tag(AppState.Mode.deck)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppState.Mode.settings)
        }
        .onAppear {
            // On a phone-sized screen the deck is the main event, not the remote desktop.
            if horizontalSizeClass == .compact, appState.mode == .remote {
                appState.mode = .deck
            }
        }
        .alert("TitanDeck was in the background",
               isPresented: Binding(get: { appState.wasBackgrounded }, set: { if !$0 { appState.dismissBackgroundWarning() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Stream Deck keys only work while TitanDeck is on screen. Check the deck is responding before carrying on.")
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
