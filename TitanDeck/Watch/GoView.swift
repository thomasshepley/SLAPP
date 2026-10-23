// Watch/GoView.swift
import SwiftUI
import WatchKit

/// One big GO. Turn the Digital Crown to pick the playback, hold the button
/// to fire (a tap from a sleeve or a flight case won't), or use double tap
/// (finger pinch) when your hands are full.
struct GoView: View {
    @EnvironmentObject private var model: WatchModel
    @State private var crown: Double = 1
    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false

    private let holdDuration: Double = 0.5

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
        return ZStack {
            // Double tap (Series 9 / Ultra 2 and later) presses this button.
            // Touches are switched off on it, so a single tap can't fire -
            // fingers only work through the hold gesture below.
            Button(action: fire) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isHolding ? 0.9 : 0.7))
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if model.isFiring {
                        ProgressView()
                    } else {
                        Text(model.kind == .go ? "GO" : "REL")
                            .font(.title2.weight(.heavy))
                    }
                }
            }
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction)
            .allowsHitTesting(false)
        }
        .frame(width: 92, height: 92)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 20) {
            fire()
        } onPressingChanged: { pressing in
            isHolding = pressing
            withAnimation(pressing ? .linear(duration: holdDuration) : .easeOut(duration: 0.15)) {
                holdProgress = pressing ? 1 : 0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.kind == .go ? "Go" : "Release") playback \(model.playback). Hold to fire.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fire() }
    }

    private func fire() {
        WKInterfaceDevice.current().play(.click)
        model.fire()
        holdProgress = 0
    }
}
