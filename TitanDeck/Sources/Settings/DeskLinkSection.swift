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

    var body: some View {
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
                        Text("Use Titan's patch report")
                        Text("Needs TitanDeck Host 0.6. On Titan: Disk > Reports > Fixtures, CSV, saved to the PC.")
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

    private var statusText: String {
        switch desk.state {
        case .off: "Off"
        case .connecting: "Looking for the desk..."
        case .linked: desk.selection.isEmpty ? "Linked" : "Linked: \(DeckFlow.selectionLabel(desk.selection) ?? "")"
        case .unavailable(let reason): reason
        }
    }
}
