// App/TitanDeckApp.swift
import SwiftUI

@main
struct TitanDeckApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear { appState.start() }
                .onOpenURL { url in appState.receiveSharedFile(url) }
        }
        .onChange(of: scenePhase) { _, phase in
            appState.scenePhaseChanged(phase)
        }
    }
}
