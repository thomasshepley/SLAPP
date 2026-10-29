// App/TitanDeckApp.swift
import SwiftUI
import UIKit

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
            // iPadOS 26 can turn the app to portrait anyway: turn it back.
            .onGeometryChange(for: Bool.self) { $0.size.height > $0.size.width } action: { tall in
                if tall { DeviceSetup.holdLandscape() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                DeviceSetup.holdLandscape()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { DeviceSetup.applyWhileOpen() }
            appState.scenePhaseChanged(phase)
        }
    }
}
