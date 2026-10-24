// Settings/FlashFadeRulesView.swift
import SwiftUI

/// Fixture ranges whose flash key fades instead of snapping: "1-99, 5 s".
/// The deck checks the number typed before Enter against these, first match wins.
struct FlashFadeRulesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                ForEach($appState.flashFadeRules) { $rule in
                    RuleRow(rule: $rule)
                }
                .onDelete { appState.flashFadeRules.remove(atOffsets: $0) }
                Button("Add a range", systemImage: "plus.circle.fill") {
                    let next = (appState.flashFadeRules.map { max($0.from, $0.to) }.max() ?? 0) + 1
                    appState.flashFadeRules.append(FlashFadeRule(from: next, to: next + 98, seconds: 5))
                }
            } footer: {
                Text("Hold the HOLD FOR 0% key after selecting a fixture with \"number Enter\": fixtures in a range fade to 0% and back over its time, everything else snaps. The fade down is done in 5% steps (Titan's set-level call has no fade time), and the way back up releases the dimmer from the deck's programmer over the time.")
            }
        }
        .navigationTitle("Flash fades")
        .toolbar { EditButton() }
    }
}

private struct RuleRow: View {
    @Binding var rule: FlashFadeRule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Fixtures")
                TextField("From", value: $rule.from, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                Text("to")
                TextField("To", value: $rule.to, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
            }
            Stepper(value: $rule.seconds, in: 0...60, step: 0.5) {
                LabeledContent("Fade", value: DeckCues.secondsText(rule.seconds))
            }
        }
        .padding(.vertical, 4)
    }
}
