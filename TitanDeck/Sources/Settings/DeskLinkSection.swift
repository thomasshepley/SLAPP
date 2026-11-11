// Settings/DeskLinkSection.swift
import SwiftUI

/// Settings > Desk link: following the desk's selection and live intensity.
/// Each part has its own switch, so anything that misbehaves on a real
/// console can be turned off without losing the rest.
struct DeskLinkSection: View {
    @ObservedObject var desk: DeskLink
    @ObservedObject var intensity: IntensityReader
    @ObservedObject var host: HostStore
    @AppStorage(SettingsKeys.showMode) private var showMode = false
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section {
            Toggle(isOn: $appState.keypadOnDesk) {
                Label("Keypad types on the desk", systemImage: "keyboard")
            }
            LabeledContent("Now") {
                Text(typingStatus)
                    .foregroundStyle(appState.keypadTypesOnDesk ? .green : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Keypad and Quick Keys")
        } footer: {
            Text("On: the deck's keypad and Quick Keys (intensity, Hold for 0%) are typed on the Titan PC, so they're on the desk's own command line and in its programmer, and show on the desk. The deck sends a whole line when you press Enter, and TitanDeck Host (0.19 or later) answers once it has really typed it, or says why not: its window must be open on the PC, and Titan the window in front. Needs this device paired with TitanDeck Host (or the remote desktop connected). Off, or with no way to type: they go through Titan's WebAPI, into the deck's own programmer, which doesn't show on the desk. Groups, FX and the colour keys always use the WebAPI.")
        }

        Section {
            Toggle(isOn: $desk.isEnabled) {
                Label("Follow the desk's selection", systemImage: "scope")
            }
            if desk.isEnabled {
                LabeledContent("Status") {
                    Text(statusText)
                        .foregroundStyle(desk.isLinked ? .green : .secondary)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Port") {
                    TextField("4434", value: $desk.port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
        } header: {
            Text(showMode ? "Desk link" : "Desk link (experimental)")
        } footer: {
            Text("Select fixtures in Layouts or on the desk and the deck brings up its intensity keys, with Currently Selected on the Remote screen. While it's linked, the deck's keys act on the desk's own programmer. Set up once on the Titan PC: TitanDeck Host > Desk selection for TitanDeck > Turn on, then restart Titan. Uses Titan's experimental UI WebAPI (Titan port 4433, passed on by the Host on 4434). If it stops answering, the deck goes back to its own WebAPI user by itself.")
        }

        Section {
            Toggle(isOn: $intensity.isEnabled) {
                Label("Live intensity on the flash key", systemImage: "light.max")
            }
            if intensity.isEnabled {
                Toggle(isOn: $intensity.usesPatchReport) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Titan's patch")
                        Text("From Titan over CITP (TitanDeck Host 0.12, Follow selection via CITP on), or a patch report saved on the PC.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !showMode {
                    Toggle(isOn: $intensity.usesPatchLookup) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Find addresses with Patch")
                            Text("Experimental. Off unless you've checked it on the console.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                if let note = intensity.note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
                if !intensity.learned.isEmpty {
                    Button("Forget \(intensity.learned.count) learnt fixture\(intensity.learned.count == 1 ? "" : "s")",
                           role: .destructive) { intensity.forgetLearned() }
                }
            }
        } footer: {
            Text("Reads the selected fixture's level from the sACN Titan sends, through TitanDeck Host\(host.isPaired ? "" : " (pair with the Host first)"). The first time you nudge or flash a fixture from the deck, TitanDeck learns which channels are its intensity, then the flash key shows its level. With Titan's patch report, the Host already knows them, so the level shows straight away (a nudge still corrects it). \(showMode ? "" : "Find addresses with Patch asks Titan's patch editor for the fixture's address first, on the deck's own WebAPI user only, never your desk's Patch window.")")
        }
    }

    private var typingStatus: String {
        if !appState.keypadOnDesk { return "Through Titan's WebAPI" }
        if host.isPaired { return "Typed on the desk by TitanDeck Host" }
        if appState.rdp.state == .connected { return "Typed on the desk through the remote desktop (not confirmed)" }
        return "Through Titan's WebAPI: pair with TitanDeck Host to type on the desk"
    }

    private var statusText: String {
        switch desk.state {
        case .off: "Off"
        case .connecting: "Looking for the desk..."
        case .linked: desk.selection.isEmpty ? "Linked" : "Linked: \(DeckFlow.selectionLabel(desk.selection) ?? "")"
        case .linkedViaCitp: desk.selection.isEmpty ? "Linked over CITP" : "Linked over CITP: \(DeckFlow.selectionLabel(desk.selection) ?? "")"
        case .unavailable(let reason): reason
        }
    }
}
