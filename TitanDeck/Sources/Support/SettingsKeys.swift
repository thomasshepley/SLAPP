// Support/SettingsKeys.swift
import Foundation

/// UserDefaults keys shared between the app and its App Intents (which can
/// run without the app's UI, so they read settings directly).
enum SettingsKeys {
    static let titanHost = "titanHost"
}
