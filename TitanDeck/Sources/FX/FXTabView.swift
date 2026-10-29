// FX/FXTabView.swift
import SwiftUI

/// The FX tab (0.37): the FX Library (moved from the Companion), and the
/// Prism setup the deck's FX page needs. Effects with a Prism Folder and File
/// show on the deck: FX > Fire, Candle, Lightning, Police, Fireworks, TV.
/// Sync with Prism (0.39) reads Prism's banks through TitanDeck Host.
struct FXTabView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(SettingsKeys.showMode) private var showMode = false
    @State private var settingUp = false

    var body: some View {
        NavigationStack {
            FXLibraryView(store: appState.fxLibrary)
                .safeAreaInset(edge: .top) {
                    if showMode {
                        Label("The deck's FX page is Test mode only for now.", systemImage: "info.circle")
                            .font(.callout)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(.thinMaterial)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if appState.syncingPrism {
                            ProgressView()
                        } else {
                            Button("Sync with Prism", systemImage: "arrow.triangle.2.circlepath") {
                                Task { await appState.syncPrism() }
                            }
                            .help("Bring in the clips Prism has, bank by bank")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Prism Setup", systemImage: "slider.horizontal.3") { settingUp = true }
                    }
                }
        }
        .sheet(isPresented: $settingUp) {
            NavigationStack { FXSettingsView() }
        }
    }
}

/// Which Titan fixtures, groups and playbacks the deck's FX page drives, and
/// the Prism personality's control names (with a check of them on Titan).
struct FXSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var probing: Int?
    @State private var probe: [Int: Result<HostFxProbe, Error>] = [:]

    var body: some View {
        Form {
            ForEach(DeckFX.layers, id: \.self) { layer in
                Section {
                    numberRow("Prism fixture", value: binding(layer, \.fixture))
                    numberRow("Pixel map group", value: binding(layer, \.group))
                    numberRow("Pixel map playback: page", value: binding(layer, \.playbackPage))
                    numberRow("Pixel map playback: fader", value: binding(layer, \.playbackFader))
                    Button {
                        Task { await check(layer) }
                    } label: {
                        if probing == layer {
                            HStack { ProgressView(); Text("Checking...") }
                        } else {
                            Label("Check the Prism fixture on Titan", systemImage: "checkmark.seal")
                        }
                    }
                    .disabled(probing != nil || appState.fxSettings.layer(layer).fixture <= 0)
                    if let result = probe[layer] { probeResult(result) }
                } header: {
                    Text("Layer \(layer)")
                } footer: {
                    Text("The Prism layer's fixture number in Titan, the group its pixel map uses (USE SEL / ADD / REMOVE replace that group), and the playback the pixel map is on (GO / STOP).")
                }
            }

            Section {
                nameRow("Brightness", \.dimmer)
                nameRow("Folder", \.folder)
                nameRow("File", \.file)
                nameRow("Speed", \.speed)
                nameRow("Contrast", \.contrast)
                nameRow("Saturation", \.saturation)
                Toggle("Levels as 0-100", isOn: $appState.fxSettings.levelsAsPercent)
            } header: {
                Text("Prism controls in Titan")
            } footer: {
                Text("The names of the Prism layer's controls as Titan's attribute editor shows them. Check the Prism fixture above to see which names Titan has. Turn off Levels as 0-100 if Titan wants 0 to 1.")
            }

            Section {
                LabeledContent("Prism's files") {
                    TextField("Found automatically", text: $appState.prismSync.folder)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Stepper(value: $appState.prismSync.firstFolder, in: 0 ... 1) {
                    LabeledContent("Prism's first bank is Folder", value: "\(appState.prismSync.firstFolder)")
                }
                Stepper(value: $appState.prismSync.firstFile, in: 0 ... 1) {
                    LabeledContent("A bank's first clip is File", value: "\(appState.prismSync.firstFile)")
                }
                Button {
                    Task { await appState.syncPrism() }
                } label: {
                    if appState.syncingPrism {
                        HStack { ProgressView(); Text("Reading Prism's banks...") }
                    } else {
                        Label("Sync with Prism now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(appState.syncingPrism)
                if let media = appState.lastPrismMedia {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(media.message).foregroundStyle(media.ok ? Color.primary : Color.red)
                        if !media.source.isEmpty {
                            Text("From " + media.source).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    .font(.callout)
                    if !media.steps.isEmpty {
                        DisclosureGroup("What TitanDeck Host looked at") {
                            ForEach(Array(media.steps.enumerated()), id: \.offset) { _, step in
                                Text(step).font(.caption.monospaced()).textSelection(.enabled)
                            }
                        }
                    }
                }
                if let error = appState.prismSyncError, error != appState.lastPrismMedia?.message {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            } header: {
                Text("Prism media")
            } footer: {
                Text("Sync with Prism has TitanDeck Host (0.18 or later) read which clips Prism has in which bank, from Prism's files on the Titan PC. Each bank is a Folder in Titan and each clip's place in its bank its File, counting from the numbers above: check one clip against Titan and change them if it's out by one. If the Host can't find Prism's files, put the folder Prism keeps its project in (or a folder of your Prism media, one subfolder per bank) in Prism's files.")
            }

            Section {
                Text("FX zones are your Titan groups whose names start with \(DeckFX.zonePrefix) (\"\(DeckFX.zonePrefix) Bar\" shows as Bar). They're on each layer's FIXTURES page.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Prism Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") { dismiss() }
            }
        }
    }

    private func binding(_ layer: Int, _ field: WritableKeyPath<DeckFX.Settings.Layer, Int>) -> Binding<Int> {
        Binding {
            appState.fxSettings.layer(layer)[keyPath: field]
        } set: { value in
            guard appState.fxSettings.layers.indices.contains(layer - 1) else { return }
            appState.fxSettings.layers[layer - 1][keyPath: field] = max(value, 0)
        }
    }

    private func numberRow(_ title: String, value: Binding<Int>) -> some View {
        LabeledContent(title) {
            TextField("Not set", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
    }

    private func nameRow(_ title: String, _ field: WritableKeyPath<DeckFX.Settings, String>) -> some View {
        LabeledContent(title) {
            TextField(title, text: Binding {
                appState.fxSettings[keyPath: field]
            } set: {
                appState.fxSettings[keyPath: field] = $0.trimmingCharacters(in: .whitespaces)
            })
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private func probeResult(_ result: Result<HostFxProbe, Error>) -> some View {
        switch result {
        case .success(let probe):
            let found = probe.controls.filter { $0.id != nil }.map(\.name)
            if found.isEmpty {
                Text(probe.steps.last ?? "Titan has none of the names asked about on fixture \(probe.fixture).")
                    .font(.callout).foregroundStyle(.red)
            } else {
                Text("Titan has: " + found.joined(separator: ", ")).font(.callout)
                let missing = appState.fxSettings.controlNames.filter { name in
                    !found.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
                }
                if !missing.isEmpty {
                    Text("Not found: " + missing.joined(separator: ", ") + ". Change those names above to ones Titan has.")
                        .font(.callout).foregroundStyle(.orange)
                }
            }
        case .failure(let error):
            Text(error.localizedDescription).font(.callout).foregroundStyle(.red)
        }
    }

    private func check(_ layer: Int) async {
        probing = layer
        defer { probing = nil }
        probe[layer] = await appState.probeFX(layer: layer)
    }
}
