// Remote/FloatingDeck.swift
import SwiftUI

/// The deck floating over the remote desktop (0.44), for when there's no
/// Stream Deck and holder to hand: a Liquid Glass panel of the deck's keys,
/// shown and hidden from the Remote screen's deck button. Drag its top strip
/// to move it, its corner to resize it; the page menu and hide are in the
/// strip too. Place and size are kept (`FloatingDeckLayout`).
struct FloatingDeck: View {
    @ObservedObject var deck: DeckSessionController
    /// The space it floats in (the Remote screen inside its safe area).
    let container: CGSize
    let onHide: () -> Void

    @AppStorage("remote.floatingDeck.width") private var widthFraction = FloatingDeckLayout.defaultWidthFraction
    @AppStorage("remote.floatingDeck.x") private var centreX = FloatingDeckLayout.defaultCentreX
    @AppStorage("remote.floatingDeck.y") private var centreY = FloatingDeckLayout.defaultCentreY
    @GestureState private var move: CGSize = .zero
    @GestureState private var resize: CGFloat = 0

    private var columns: Int { deck.profile.gridColumns }

    var body: some View {
        let layout = deckFrame(move: move, resize: resize)
        VStack(spacing: 0) {
            bar
                .frame(height: FloatingDeckLayout.barHeight)
                .contentShape(.rect)
                .gesture(moveGesture)
            DeckKeyGrid(deck: deck, columns: columns, side: layout.side, spacing: FloatingDeckLayout.spacing)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FloatingDeckLayout.padding)
        .padding(.bottom, FloatingDeckLayout.padding)
        .frame(width: CGFloat(layout.width), height: CGFloat(layout.height), alignment: .top)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .overlay(alignment: .bottomTrailing) { resizeHandle }
        .position(x: CGFloat(layout.centreX), y: CGFloat(layout.centreY))
    }

    private func deckFrame(move: CGSize, resize: CGFloat) -> FloatingDeckLayout.Frame {
        FloatingDeckLayout.frame(keyCount: deck.profile.keyCount, columns: columns,
                                 containerWidth: Double(container.width), containerHeight: Double(container.height),
                                 widthFraction: widthFraction, centreX: centreX, centreY: centreY,
                                 move: (Double(move.width), Double(move.height)), resize: Double(resize))
    }

    /// Grip, the page (a menu of the deck's pages) and hide.
    private var bar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Menu {
                ForEach(deck.profile.pages.indices, id: \.self) { index in
                    Button(deck.profile.pages[index].name) { deck.showPage(index) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(deck.isShowingMenu ? "Main Menu" : (deck.currentPage?.name ?? "Deck"))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel("Deck page")
            Spacer(minLength: 0)
            Button(action: onHide) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide the deck")
        }
        .font(.subheadline.weight(.semibold))
    }

    /// The bottom-right corner: drag it to make the deck bigger or smaller.
    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.caption.weight(.bold))
            .frame(width: 30, height: 30)
            .glassEffect(.regular.interactive(), in: .circle)
            .offset(x: 10, y: 10)
            .gesture(resizeGesture)
            .accessibilityLabel("Resize the deck")
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 40.0 : -40.0
                commit(deckFrame(move: .zero, resize: CGFloat(step)))
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .updating($move) { value, state, _ in state = value.translation }
            .onEnded { value in commit(deckFrame(move: value.translation, resize: 0)) }
    }

    /// Dragging the corner out (right or down) makes it bigger.
    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .updating($resize) { value, state, _ in state = Self.growth(value.translation) }
            .onEnded { value in commit(deckFrame(move: .zero, resize: Self.growth(value.translation))) }
    }

    private static func growth(_ translation: CGSize) -> CGFloat {
        // Mostly sideways, a little for down, so a diagonal drag feels natural.
        (translation.width + translation.height) / 2
    }

    /// Keeps where it ended up, as fractions of the space.
    private func commit(_ frame: FloatingDeckLayout.Frame) {
        guard container.width > 0, container.height > 0 else { return }
        widthFraction = frame.width / Double(container.width)
        centreX = frame.centreX / Double(container.width)
        centreY = frame.centreY / Double(container.height)
    }
}
