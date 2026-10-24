// Remote/KeypadReadoutBar.swift
import SwiftUI

/// Keeps the keypad readout and runs its Enter animation: the line goes
/// green where it was typed, then slides across into the last commands.
@MainActor
final class KeypadReadoutStore: ObservableObject {
    @Published private(set) var readout = KeypadReadout()
    /// A line just sent with Enter, still shown green on the left before it moves.
    @Published private(set) var flashingID: UUID?
    private var moveTask: Task<Void, Never>?

    static let flashDuration: Duration = .milliseconds(350)

    /// Feeds a deck key press. Returns the line id to report Titan's answer to.
    func press(_ action: TitanAction) -> UUID? {
        guard KeypadReadout.isKeypad(action) else { return nil }
        // Typing again before the last line has moved: move it now.
        if flashingID != nil { finishMove() }
        let id = withAnimation(.snappy(duration: 0.2)) { readout.press(action) }
        if case .keypadEnter = action, let id {
            flashingID = id
            moveTask = Task { [weak self] in
                try? await Task.sleep(for: Self.flashDuration)
                guard !Task.isCancelled else { return }
                self?.finishMove()
            }
        }
        return id
    }

    func markAnswered(_ id: UUID, ok: Bool) {
        withAnimation(.snappy) { readout.markAnswered(id, ok: ok) }
    }

    private func finishMove() {
        moveTask?.cancel()
        moveTask = nil
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) { flashingID = nil }
    }
}

/// The keypad readout in the black band under the remote desktop: what's
/// being typed on the left, the last three commands on the right.
struct KeypadReadoutBar: View {
    @ObservedObject var store: KeypadReadoutStore
    /// Height available; the text scales to it.
    let height: CGFloat
    @Namespace private var namespace

    private var readout: KeypadReadout { store.readout }
    private var flashing: KeypadReadout.Entry? {
        store.flashingID.flatMap { id in readout.history.first { $0.id == id } }
    }
    private var settled: [KeypadReadout.Entry] { readout.history.filter { $0.id != store.flashingID } }
    private var fontSize: CGFloat { min(40, max(18, height * 0.42)) }
    private var showsCaptions: Bool { height >= 70 }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                if showsCaptions { caption("KEYPAD") }
                typing
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 2) {
                if showsCaptions { caption(readout.history.isEmpty ? " " : "LAST COMMANDS") }
                lastCommands
            }
        }
        .padding(.horizontal, 28)
        .frame(height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Left: the line being typed

    @ViewBuilder
    private var typing: some View {
        if let flashing {
            CommandText(text: flashing.text, size: fontSize, colour: .green, weight: .bold)
                .matchedGeometryEffect(id: flashing.id, in: namespace)
        } else if let current = readout.current {
            HStack(spacing: 4) {
                CommandText(text: current.text, size: fontSize,
                            colour: current.delivery == .failed ? .red : .white, weight: .semibold)
                    .matchedGeometryEffect(id: current.id, in: namespace)
                BlinkingCaret(height: fontSize * 0.9)
            }
        } else {
            HStack(spacing: 4) {
                BlinkingCaret(height: fontSize * 0.9)
                Text("Type on the keypad")
                    .font(.system(size: fontSize * 0.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Right: the last three commands, newest on the right

    private var lastCommands: some View {
        HStack(alignment: .lastTextBaseline, spacing: 18) {
            ForEach(Array(settled.enumerated()), id: \.element.id) { index, entry in
                let isNewest = index == settled.count - 1 && flashing == nil
                HStack(spacing: 6) {
                    if entry.delivery == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: fontSize * (isNewest ? 0.5 : 0.35)))
                            .foregroundStyle(.red)
                    }
                    CommandText(text: entry.text, size: fontSize * (isNewest ? 0.85 : 0.5),
                                colour: colour(for: entry, isNewest: isNewest),
                                weight: isNewest ? .bold : .medium)
                }
                .matchedGeometryEffect(id: entry.id, in: namespace)
            }
        }
    }

    private func colour(for entry: KeypadReadout.Entry, isNewest: Bool) -> Color {
        switch entry.delivery {
        case .failed: Color.red
        case .sending, .sent: isNewest ? Color.green : Color.green.opacity(0.45)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.4))
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let current = readout.current { parts.append("Typing \(current.text)") }
        if let last = readout.lastCommand { parts.append("Last command \(last.text)") }
        return parts.isEmpty ? "Keypad readout, empty" : parts.joined(separator: ", ")
    }
}

private struct CommandText: View {
    let text: String
    let size: CGFloat
    let colour: Color
    let weight: Font.Weight

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundStyle(colour)
            .lineLimit(1)
            .fixedSize()
    }
}

private struct BlinkingCaret: View {
    let height: CGFloat
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white.opacity(on ? 0.85 : 0.15))
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
