// App/RootView.swift
import SwiftUI

/// Remote view full screen by default; Settings is one tab away, or opened by
/// a deck key with the openSettings action.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.mode) {
            RemotePlaceholderView()
                .tabItem { Label("Remote", systemImage: "display") }
                .tag(AppState.Mode.remote)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppState.Mode.settings)
        }
        .alert("TitanDeck was in the background",
               isPresented: Binding(get: { appState.wasBackgrounded }, set: { if !$0 { appState.dismissBackgroundWarning() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Stream Deck keys only work while TitanDeck is on screen. Check the deck is responding before carrying on.")
        }
    }
}

/// Stands in for the FreeRDP view until milestone M5.
private struct RemotePlaceholderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Remote view - M5")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                DeckStatusLine(deck: appState.deck)
            }
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
