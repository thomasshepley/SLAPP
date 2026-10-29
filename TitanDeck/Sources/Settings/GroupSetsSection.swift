// Settings/GroupSetsSection.swift
import SwiftUI

/// Settings > Deck > Groups page: the sets of groups the deck's Groups page
/// (Nothing Selected) offers, their names, and which Titan Groups page is
/// set 1 (the next sets follow).
struct GroupSetsSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section {
            Stepper(value: Binding { appState.groupSettings.names.count } set: { setCount($0) }, in: 1 ... 20) {
                LabeledContent("Sets", value: "\(appState.groupSettings.names.count)")
            }
            Stepper(value: $appState.groupSettings.firstPage, in: 1 ... 99) {
                LabeledContent("Set 1 is Titan's Groups page", value: "\(appState.groupSettings.firstPage)")
            }
            ForEach(appState.groupSettings.names.indices, id: \.self) { set in
                LabeledContent("Groups page \(appState.groupSettings.titanPage(set) + 1)") {
                    TextField("Set \(set + 1)", text: Binding {
                        appState.groupSettings.names.indices.contains(set) ? appState.groupSettings.names[set] : ""
                    } set: { name in
                        guard appState.groupSettings.names.indices.contains(set) else { return }
                        appState.groupSettings.names[set] = name
                    })
                    .multilineTextAlignment(.trailing)
                }
            }
            Picker("In use", selection: $appState.groupSettings.chosen) {
                Text("Ask on the deck").tag(Int?.none)
                ForEach(appState.groupSettings.names.indices, id: \.self) { set in
                    Text(appState.groupSettings.name(set)).tag(Int?.some(set))
                }
            }
        } header: {
            Text("Groups page")
        } footer: {
            Text("With nothing selected, pressing Nothing Selected on the keypad shows the groups of the set in use (each set is a page of Titan's Groups window). Pressing a group selects it on the desk and goes to Quick Keys. SET on the deck changes the set.")
        }
    }

    private func setCount(_ count: Int) {
        var names = appState.groupSettings.names
        while names.count < count { names.append("Set \(names.count + 1)") }
        names = Array(names.prefix(max(count, 1)))
        appState.groupSettings.names = names
        if let chosen = appState.groupSettings.chosen, chosen >= names.count { appState.groupSettings.chosen = nil }
    }
}
