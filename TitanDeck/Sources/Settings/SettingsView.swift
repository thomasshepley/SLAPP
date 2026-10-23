// Settings/SettingsView.swift
import SwiftUI
#if DEBUG
import StreamDeckSimulator
#endif

/// M3 settings: Titan host, connection test, test fire buttons and a latency
/// log. The deck editor (DeckEditorView / KeyInspectorView) arrives in M4.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                testSection
                DeckSection(deck: appState.deck)
                logSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    private var connectionSection: some View {
        Section {
            LabeledContent("Titan PC address") {
                TextField("e.g. 192.168.1.20", text: $appState.titanHost)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 260)
            }
            HStack {
                Button("Test connection") { appState.checkConnection() }
                    .disabled(appState.titanHost.isEmpty || appState.isCheckingConnection)
                Spacer()
                if appState.isCheckingConnection {
                    ProgressView()
                } else if let version = appState.titanVersion {
                    Label("Titan \(version)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("WebAPI on port \(TitanEndpoints.defaultPort). Enable it in Titan's User Settings and allow TCP \(TitanEndpoints.defaultPort) through the PC firewall.")
        }
    }

    private var testSection: some View {
        Section("Test") {
            Button("Fire test playback 1") { appState.fire(.playbackGo(userNumber: 1)) }
            Button("Release playback 1") { appState.fire(.playbackRelease(userNumber: 1)) }
        }
        .disabled(appState.titanHost.isEmpty)
    }

    private var logSection: some View {
        Section("Recent calls") {
            if appState.recentResults.isEmpty {
                Text("Nothing sent yet").foregroundStyle(.secondary)
            }
            ForEach(Array(appState.recentResults.enumerated()), id: \.offset) { _, result in
                HStack {
                    Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(result.ok ? .green : .red)
                    Text(result.action.summary)
                    Spacer()
                    Text(result.ok ? "\(result.milliseconds) ms" : (result.error ?? "HTTP \(result.statusCode ?? 0)"))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.versionString)
        }
    }
}

private struct DeckSection: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var deck: DeckSessionController
    @State private var confirmReset = false

    var body: some View {
        Section("Stream Deck") {
            LabeledContent("Driver", value: deck.statusText)
            if let device = deck.device {
                LabeledContent("Device", value: device.info.productName)
                LabeledContent("Keys", value: "\(device.capabilities.keyCount) (\(device.capabilities.keyColumns) x \(device.capabilities.keyRows))")
            } else {
                LabeledContent("Device", value: "None attached")
            }
            LabeledContent("Profile", value: "\(deck.profile.name) - \(deck.profile.pages.count) pages")
            NavigationLink {
                DeckEditorView(deck: deck)
            } label: {
                Label("Edit deck profile", systemImage: "square.grid.3x3.fill")
            }
            #if DEBUG
            Button("Show on-screen Stream Deck (debug)", systemImage: "rectangle.grid.2x2") {
                StreamDeckSimulator.show(defaultStreamDeck: .xl)
            }
            #endif
            Button("Reset to default profile", role: .destructive) { confirmReset = true }
                .confirmationDialog("Replace the current deck profile with the default?",
                                    isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { appState.resetProfileToDefault() }
                }
        }
    }
}

private extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
