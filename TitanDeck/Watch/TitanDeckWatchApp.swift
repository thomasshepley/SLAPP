// Watch/TitanDeckWatchApp.swift
import SwiftUI

@main
struct TitanDeckWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            // Cues first, the numbered GO button a swipe to the side. Pages
            // go sideways so the Digital Crown stays free for the cue list
            // and for picking a playback number.
            TabView {
                NavigationStack { CuesView() }
                GoView()
            }
            .tabViewStyle(.page)
            .environmentObject(model)
            .onAppear { model.start() }
        }
    }
}
