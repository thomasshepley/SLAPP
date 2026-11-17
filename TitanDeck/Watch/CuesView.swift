// Watch/CuesView.swift
import SwiftUI
import WatchKit

/// The cues the iPhone shares (0.46.1): the deck's GO keys first, then
/// Titan's other named playbacks. Tap one to fire it; swipe it left to
/// release it. The Digital Crown scrolls the list.
struct CuesView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        let onDeck = model.cues.filter(\.onDeck)
        let others = model.cues.filter { !$0.onDeck }
        List {
            if let outcome = model.outcome {
                Text(outcome.text)
                    .font(.caption2)
                    .foregroundStyle(outcome.ok ? .green : .red)
                    .listRowBackground(Color.clear)
            }
            if !onDeck.isEmpty {
                Section("On the deck") {
                    ForEach(onDeck) { row($0) }
                }
            }
            if !others.isEmpty {
                Section(onDeck.isEmpty ? "Cues" : "More from Titan") {
                    ForEach(others) { row($0) }
                }
            }
            if model.cues.isEmpty {
                Text("No cues yet. Open TitanDeck on your iPhone while it's connected to Titan: its GO keys and Titan's named playbacks appear here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Cues")
    }

    private func row(_ cue: WatchCue) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            model.fire(cue, release: false)
        } label: {
            HStack {
                Text(cue.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                if model.firingCue == cue.titanId {
                    ProgressView()
                        .frame(width: 20)
                } else {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Release") {
                WKInterfaceDevice.current().play(.click)
                model.fire(cue, release: true)
            }
            .tint(.red)
        }
        .accessibilityLabel("Go \(cue.title)")
        .accessibilityHint("Swipe left to release it")
    }
}
