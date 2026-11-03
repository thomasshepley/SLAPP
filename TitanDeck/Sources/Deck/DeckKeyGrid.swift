// Deck/DeckKeyGrid.swift
import SwiftUI

/// The deck's keys as touch buttons, `columns` across at `side` points each:
/// down on touch, up on release, so a Go key behaves like the hardware. Same
/// profile, paging, red failure flash and live-playback lights as the
/// hardware. Shared by the Deck tab and the floating deck on the Remote
/// screen (0.44).
struct DeckKeyGrid: View {
    @ObservedObject var deck: DeckSessionController
    let columns: Int
    let side: Double
    var spacing: Double = OnScreenDeckLayout.spacing
    @State private var pressedKey: Int?
    @State private var pressCount = 0

    var body: some View {
        let items = Array(repeating: GridItem(.fixed(CGFloat(side)), spacing: CGFloat(spacing)), count: max(columns, 1))
        LazyVGrid(columns: items, spacing: CGFloat(spacing)) {
            ForEach(0..<deck.profile.keyCount, id: \.self) { index in
                key(index)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pressCount)
    }

    private func key(_ index: Int) -> some View {
        let key = deck.displayedKey(at: index)
        return Image(uiImage: DeckRenderer.image(for: key, size: CGSize(width: 144, height: 144),
                                                 overlay: deck.overlays[index] ?? .none,
                                                 isActive: deck.isActive(key), isLatched: deck.isLatched(key),
                                                 heldHex: deck.heldColorHex))
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: CGFloat(side), height: CGFloat(side))
            .clipShape(RoundedRectangle(cornerRadius: min(12, CGFloat(side) * 0.12), style: .continuous))
            .scaleEffect(pressedKey == index ? 0.94 : 1)
            .animation(.snappy(duration: 0.12), value: pressedKey)
            .opacity(key == nil ? 0.25 : 1)
            .gesture(pressGesture(index: index, enabled: key?.action != nil))
            .accessibilityElement()
            .accessibilityLabel(key.map { $0.label.replacingOccurrences(of: "\n", with: " ") } ?? "Empty key")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { press(index) }
    }

    /// Down on touch, up on release - so a Go key behaves like the hardware.
    private func pressGesture(index: Int, enabled: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard enabled, pressedKey != index else { return }
                pressedKey = index
                pressCount += 1
                deck.pressOnScreenKey(index, pressed: true)
            }
            .onEnded { _ in
                guard pressedKey == index else { return }
                pressedKey = nil
                deck.pressOnScreenKey(index, pressed: false)
            }
    }

    private func press(_ index: Int) {
        deck.pressOnScreenKey(index, pressed: true)
        deck.pressOnScreenKey(index, pressed: false)
    }
}
