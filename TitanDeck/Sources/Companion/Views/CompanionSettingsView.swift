// Companion/Views/CompanionSettingsView.swift
import SwiftUI

/// Units, mains frequency and supply voltage used across the tools.
struct CompanionSettingsView: View {
    @AppStorage(CompanionSettings.unitsKey) private var unitSystem: UnitSystem = .metric
    @AppStorage(CompanionSettings.mainsHzKey) private var mainsHz: Int = 50
    @AppStorage(CompanionSettings.voltageKey) private var voltage: Double = 230

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Metres, lux and kilograms, or feet, footcandles and pounds.")
            }
            Section {
                Picker("Mains frequency", selection: $mainsHz) {
                    Text("50 Hz (UK, Europe)").tag(50)
                    Text("60 Hz (US, Japan west)").tag(60)
                }
                Picker("Supply voltage", selection: $voltage) {
                    Text("230 V").tag(230.0)
                    Text("240 V").tag(240.0)
                    Text("120 V").tag(120.0)
                    Text("110 V").tag(110.0)
                }
            } header: {
                Text("Mains")
            } footer: {
                Text("Used by the flicker check and the power budget.")
            }
        }
        .navigationTitle(CompanionSection.settings.title)
    }
}
