// Watch/GoView.swift
import SwiftUI
import WatchKit

/// One big GO. Turn the Digital Crown to pick the playback, tap the button
/// to fire (0.43.1: a tap, not a hold), or use double tap (finger pinch) when
/// your hands are full.
struct GoView: View {
    @EnvironmentObject private var model: WatchModel
    @State private var crown: Double = 1

    var body: some View {
        VStack(spacing: 6) {
            // GO / REL switch (segmented pickers don't exist on watchOS).
            Button {
                model.kind = model.kind == .go ? .release : .go
            } label: {
                Text(model.kind == .go ? "GO  ·  tap for REL" : "REL  ·  tap for GO")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(model.kind == .go ? .green : .red)

            Text("PB \(model.playback)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .focusable()
                .digitalCrownRotation($crown, from: 1, through: 999, by: 1, sensitivity: .medium,
                                      isContinuous: false, isHapticFeedbackEnabled: true)
                .onChange(of: crown) { _, value in model.playback = Int(value.rounded()) }

            goButton

            if let outcome = model.outcome {
                Text(outcome.text)
                    .font(.caption2)
                    .foregroundStyle(outcome.ok ? .green : .red)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .onAppear { crown = Double(model.playback) }
    }

    private var goButton: some View {
        let color: Color = model.kind == .go ? .green : .red
        // Double tap (Series 9 / Ultra 2 and later) presses this button too.
        return Button(action: fire) {
            ZStack {
                Circle()
                    .fill(color)
                if model.isFiring {
                    ProgressView()
                } else {
                    Text(model.kind == .go ? "GO" : "REL")
                        .font(.title2.weight(.heavy))
                }
            }
        }
        .buttonStyle(PressStyle())
        .handGestureShortcut(.primaryAction)
        .frame(width: 92, height: 92)
        .contentShape(Circle())
        .accessibilityLabel("\(model.kind == .go ? "Go" : "Release") playback \(model.playback)")
    }

    private func fire() {
        WKInterfaceDevice.current().play(.click)
        model.fire()
    }
}

/// Dims and shrinks the GO button while a finger is on it.
private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
