// Deck/OnScreenDeckView.swift
import SwiftUI

/// The deck as touch buttons, for iPhone (Stream Deck Kit is iPad-only) or an
/// iPad with no Stream Deck plugged in. Same profile, paging, red failure flash
/// and live-playback lights as the hardware.
///
/// 0.43: the keys keep the physical deck's layout and fill the space
/// (`OnScreenDeckLayout`). Held upright (iPhone, iPhone Duo folded or open
/// in portrait) the command line, what's selected and the pages sit above
/// the keys. Wider than tall (iPhone Duo open like a book, iPad, a phone on
/// its side) it's two sides: selection, level, CCT and pages on the
/// leading side, the keys on the trailing side, clear of the fold.
struct OnScreenDeckView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var deck: DeckSessionController
    @State private var pressedKey: Int?
    @State private var pressCount = 0
    /// Titan's command line, shown while the deck is on screen.
    @State private var commandLine: String?

    private static let margin = 16.0

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = max(0, proxy.size.width - 2 * Self.margin)
                let height = max(0, proxy.size.height - 2 * Self.margin)
                layout(width: width, height: height)
                    .padding(Self.margin)
            }
            .background(Color.black)
            .navigationTitle(deck.isShowingMenu ? "Main Menu" : (deck.currentPage?.name ?? "Deck"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                ForEach(deck.profile.pages.indices, id: \.self) { index in
                    Button(deck.profile.pages[index].name) { deck.showPage(index) }
                }
            }
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
    private func layout(width: Double, height: Double) -> some View {
        switch OnScreenDeckLayout.arrangement(keyCount: deck.profile.keyCount, deckColumns: deck.profile.gridColumns,
                                              width: width, height: height) {
        case .sideBySide:
            let half = OnScreenDeckLayout.halfWidth(width)
            HStack(spacing: OnScreenDeckLayout.foldGap) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        commandLineBar
                        SelectionCard(deck: deck)
                        pageList
                    }
                }
                .scrollIndicators(.hidden)
                .frame(width: half)
                // The keys on the outer edge, under the thumb and away from the fold.
                keys(width: half, height: height, alignment: .trailing)
                    .frame(width: half)
            }
        case .stacked:
            VStack(spacing: 14) {
                commandLineBar
                // Room kept for the strip, so the keys don't jump when something's selected.
                ZStack {
                    Color.clear.frame(height: 34)
                    SelectionStrip(deck: deck)
                }
                pageBar
                GeometryReader { proxy in
                    keys(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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

    /// The pages in a row that scrolls sideways, above the keys.
    @ViewBuilder
    private var pageBar: some View {
        if deck.isShowingMenu {
            Text("Main menu - pick a layout")
                .font(.headline)
                .foregroundStyle(.secondary)
        } else if deck.profile.pages.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(deck.profile.pages.indices, id: \.self) { index in
                        pageButton(index, fullWidth: false)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// The pages as a list, on the selection side.
    private var pageList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pages")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if deck.isShowingMenu {
                Text("Main menu - pick a layout on the keys")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(deck.profile.pages.indices, id: \.self) { index in
                pageButton(index, fullWidth: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func pageButton(_ index: Int, fullWidth: Bool) -> some View {
        let label = Text(deck.profile.pages[index].name)
            .lineLimit(1)
            .frame(maxWidth: fullWidth ? CGFloat.infinity : nil, alignment: .leading)
        if !deck.isShowingMenu && index == deck.currentPageIndex {
            Button { deck.showPage(index) } label: { label }
                .buttonStyle(.glassProminent)
        } else {
            Button { deck.showPage(index) } label: { label }
                .buttonStyle(.glass)
        }
    }

    /// The keys in the deck's own layout, as big as fit (scrolling only when
    /// even reflowed they can't), placed by `alignment` in the space.
    @ViewBuilder
    private func keys(width: Double, height: Double, alignment: Alignment) -> some View {
        let grid = OnScreenDeckLayout.grid(keyCount: deck.profile.keyCount, deckColumns: deck.profile.gridColumns,
                                           width: width, height: height)
        let columns = Array(repeating: GridItem(.fixed(CGFloat(grid.side)), spacing: CGFloat(OnScreenDeckLayout.spacing)),
                            count: grid.columns)
        let content = LazyVGrid(columns: columns, spacing: CGFloat(OnScreenDeckLayout.spacing)) {
            ForEach(0..<deck.profile.keyCount, id: \.self) { index in
                key(index, side: grid.side)
            }
        }
        if grid.scrolls {
            ScrollView {
                content.frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        } else {
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
    }

    private func key(_ index: Int, side: Double) -> some View {
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

/// What's selected, its level and colour temperature, as a card for the
/// on-screen deck's selection side (0.43). A tap on the fixtures lists them all.
struct SelectionCard: View {
    @ObservedObject var deck: DeckSessionController
    @State private var showingAll = false

    var body: some View {
        let fixtures = deck.selectedFixtures
        VStack(alignment: .leading, spacing: 14) {
            Label("Selected", systemImage: "scope")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if fixtures.isEmpty {
                Text("Nothing selected")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showingAll = true
                } label: {
                    Text(DeckFlow.selectionRuns(fixtures).joined(separator: ", "))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingAll) {
                    SelectionList(fixtures: fixtures)
                }
                .accessibilityLabel("Selected fixtures: \(DeckFlow.selectionRuns(fixtures).joined(separator: ", "))")
            }
            HStack(spacing: 12) {
                reading("Level", value: DeckFlow.percentText(deck.liveLevel ?? deck.typedLevel),
                        symbol: "light.max", tint: .primary)
                reading("CCT", value: deck.currentKelvin.map { "\($0)K" } ?? "-",
                        symbol: "thermometer.sun.fill",
                        tint: deck.currentKelvin.map { Color(kelvin: Double($0)) } ?? .primary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .animation(.snappy, value: fixtures)
    }

    private func reading(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
