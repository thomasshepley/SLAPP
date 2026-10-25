// Support/SettingsKeys.swift
import Foundation

/// UserDefaults keys shared between the app and its App Intents (which can
/// run without the app's UI, so they read settings directly).
enum SettingsKeys {
    static let titanHost = "titanHost"
    /// Whether the Remote (desktop) tab is shown. Off by default on iPhone,
    /// where the app is mainly the Companion and Titan commands.
    static let remoteDesktopEnabled = "remoteDesktopEnabled"
    /// Show mode (true) or Test mode: Show hides the test tools and turns
    /// the experimental ones off (Settings > Mode).
    static let showMode = "app.showMode"
}
