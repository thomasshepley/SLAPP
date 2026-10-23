// Watch/TitanDeckWatchApp.swift
import SwiftUI

@main
struct TitanDeckWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            GoView()
                .environmentObject(model)
                .onAppear { model.start() }
        }
    }
}
