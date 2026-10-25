// App/TitanDeckApp.swift
import SwiftUI

@main
struct TitanDeckApp: App {
    @UIApplicationDelegateAdaptor(TitanDeckAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if appState.showingStartup {
                    // Health checks first; the deck shows the logo meanwhile.
                    StartupView {
                        withAnimation(.easeOut(duration: 0.25)) { appState.finishStartup() }
                    }
                    .transition(.opacity)
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(.dark)
            .onAppear {
                appState.start()
                CompanionLibrary.warmUp()
                DeviceSetup.applyWhileOpen()
            }
            .onOpenURL { url in appState.receiveSharedFile(url) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { DeviceSetup.applyWhileOpen() }
            appState.scenePhaseChanged(phase)
        }
    }
}
