// Deck/OnScreenDeckView.swift
import SwiftUI

/// The deck as touch buttons, for iPhone (Stream Deck Kit is iPad-only) or an
/// iPad with no Stream Deck plugged in. Same profile, paging, red failure flash
/// and live-playback lights as the hardware.
struct OnScreenDeckView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var deck: DeckSessionController
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var pressedKey: Int?
    @State private var pressCount = 0
    /// Titan's command line, shown while the deck is on screen.
    @State private var commandLine: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    commandLineBar
                    if deck.isShowingMenu {
                        Text("Main menu - pick a layout")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else if deck.profile.pages.count > 1 {
                        Picker("Page", selection: pageBinding) {
                            ForEach(deck.profile.pages.indices, id: \.self) { index in
                                Text(deck.profile.pages[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    grid
                }
                .padding()
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .background(Color.black)
            .navigationTitle(deck.isShowingMenu ? "Main Menu" : (deck.currentPage?.name ?? "Deck"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionDot(heartbeat: appState.heartbeat)
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: pressCount)
            .task {
                // Poll the command line twice a second while this tab is open.
                while !Task.isCancelled {
                    commandLine = await appState.titan.commandLineText()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
    }

    @ViewBuilder
    private var commandLineBar: some View {
        if let commandLine {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                Text(commandLine.isEmpty ? " " : commandLine)
                    .font(.title3.monospaced())
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .accessibilityLabel("Titan command line: \(commandLine)")
        }
    }

    private var pageBinding: Binding<Int> {
        Binding(get: { deck.currentPageIndex }, set: { deck.showPage($0) })
    }

    private var grid: some View {
        let columnCount = OnScreenDeckLayout.columns(
            keyCount: deck.profile.keyCount, deckColumns: deck.profile.gridColumns,
            isCompactWidth: horizontalSizeClass == .compact, isCompactHeight: verticalSizeClass == .compact)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<deck.profile.keyCount, id: \.self) { index in
                let key = deck.displayedKey(at: index)
                Image(uiImage: DeckRenderer.image(for: key, size: CGSize(width: 144, height: 144),
                                                  overlay: deck.overlays[index] ?? .none,
                                                  isActive: deck.isActive(key), isLatched: deck.isLatched(key)))
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .scaleEffect(pressedKey == index ? 0.94 : 1)
                    .animation(.snappy(duration: 0.12), value: pressedKey)
                    .opacity(key == nil ? 0.25 : 1)
                    .gesture(pressGesture(index: index, enabled: key?.action != nil))
                    .accessibilityElement()
                    .accessibilityLabel(key.map { $0.label.replacingOccurrences(of: "\n", with: " ") } ?? "Empty key")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { press(index) }
            }
        }
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

/// Small Titan-reachability dot for toolbars.
struct ConnectionDot: View {
    @ObservedObject var heartbeat: TitanHeartbeat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .accessibilityLabel(heartbeat.health.isReachable ? "Titan connected" : "Titan not connected")
    }

    private var color: Color {
        switch heartbeat.health {
        case .ok: return .green
        case .slow: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
