// Settings/ModeSection.swift
import SwiftUI

/// Settings > Mode: Test or Show. Show hides the test tools (test fire
/// buttons, the virtual Stream Deck, the call and soak logs) and turns the
/// experimental Patch lookup off, so Settings is the production version.
/// Going to Show is confirmed first.
struct ModeSection: View {
    @AppStorage(SettingsKeys.showMode) private var showMode = false
    @ObservedObject var intensity: IntensityReader
    @State private var confirmShow = false
    @State private var confirmTest = false

    var body: some View {
        Section {
            Picker("Mode", selection: Binding(
                get: { showMode },
                set: { wantsShow in
                    guard wantsShow != showMode else { return }
                    if wantsShow { confirmShow = true } else { confirmTest = true }
                })) {
                Text("Test").tag(false)
                Text("Show").tag(true)
            }
            .pickerStyle(.segmented)
            .alert("Switch to Show mode?", isPresented: $confirmShow) {
                Button("Cancel", role: .cancel) {}
                Button("Switch to Show", role: .destructive) { switchToShow() }
            } message: {
                Text("All test features will be disabled if you confirm this.")
            }
            .alert("Switch to Test mode?", isPresented: $confirmTest) {
                Button("Cancel", role: .cancel) {}
                Button("Switch to Test") { showMode = false }
            } message: {
                Text("The test tools come back in Settings.")
            }
        } header: {
            HStack {
                Text("Mode")
                Spacer()
                ModeBadge()
            }
        } footer: {
            Text(showMode
                 ? "Show mode: the production settings only. Test tools are hidden and experimental features are off."
                 : "Test mode: test tools and experimental features are available. Switch to Show for a show.")
        }
    }

    private func switchToShow() {
        intensity.usesPatchLookup = false   // experimental: never on in a show
        showMode = true
    }
}
