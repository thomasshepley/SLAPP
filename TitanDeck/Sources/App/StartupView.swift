// App/StartupView.swift
import SwiftUI
import UIKit

/// Shown at launch: the TitanDeck logo, then a health check of everything the
/// show needs, and Continue. Meanwhile the Stream Deck shows the logo with a
/// shine across it, so you can see the deck is alive. Sideways (0.43) the
/// checks get a side of their own.
struct StartupView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var checks = StartupChecks()
    @AppStorage(SettingsKeys.remoteDesktopEnabled)
    private var remoteDesktopEnabled = UIDevice.current.userInterfaceIdiom != .phone
    @AppStorage(SettingsKeys.showMode) private var showMode = false
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea()
            GeometryReader { proxy in
                // Sideways with room (iPhone Duo open like a book, iPad, a phone
                // on its side): the logo and buttons on one side, the checks on
                // the other, nothing on the fold. Upright: one column.
                if proxy.size.width > proxy.size.height * 1.15 && proxy.size.width >= 640 {
                    HStack(spacing: 40) {
                        ScrollView {
                            VStack(spacing: 28) {
                                header
                                footer
                            }
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                        }
                        ScrollView {
                            checkList
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            header
                                .padding(.top, 40)
                            checkList
                            footer
                                .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: start)
    }

    private var header: some View {
        VStack(spacing: 14) {
            TitanDeckLogo()
                .frame(width: 132, height: 132)
            Text("TitanDeck")
                .font(.largeTitle.weight(.bold))
            HStack(spacing: 8) {
                Text("Version \(Bundle.main.shortVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ModeBadge()
            }
        }
    }

    private var checkList: some View {
        VStack(spacing: 0) {
            ForEach(checks.rows) { row in
                CheckRow(row: row)
                if row.id != checks.rows.last?.id { Divider().padding(.leading, 52) }
            }
        }
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .frame(maxWidth: 620)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                Button("Check again", systemImage: "arrow.clockwise") { start() }
                    .buttonStyle(.bordered)
                    .disabled(!checks.isDone)
                Button(action: onContinue) {
                    Text("Continue").frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!checks.isDone)
            }
        }
    }

    private var summary: String {
        guard checks.isDone else { return "Checking the show setup..." }
        switch checks.warnings {
        case 0: return "All good."
        case 1: return "One thing to look at. You can carry on anyway."
        default: return "\(checks.warnings) things to look at. You can carry on anyway."
        }
    }

    private func start() {
        checks.start(appState, remoteDesktop: remoteDesktopEnabled, showMode: showMode)
    }

    private struct CheckRow: View {
        let row: StartupChecks.Row

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: row.symbol)
                    .font(.title3)
                    .frame(width: 26)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.headline)
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                status
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
        }

        @ViewBuilder
        private var status: some View {
            switch row.state {
            case .checking:
                ProgressView()
            case .ok:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.title3)
            case .off:
                Image(systemName: "minus.circle").foregroundStyle(.secondary).font(.title3)
            }
        }
    }
}

/// The app icon's 4 x 4 keys, with the same shine the deck shows while loading.
struct TitanDeckLogo: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { context in
            let frame = Int(context.date.timeIntervalSinceReferenceDate * 10)
            let page = DeckFlow.splashPage(columns: 4, keyCount: 16, frame: frame)
            GeometryReader { proxy in
                let gap = proxy.size.width * 0.05
                let side = (proxy.size.width - gap * 3) / 4
                VStack(spacing: gap) {
                    ForEach(0 ..< 4, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0 ..< 4, id: \.self) { column in
                                RoundedRectangle(cornerRadius: side * 0.2, style: .continuous)
                                    .fill(Color(uiColor: UIColor(hex: page.key(at: row * 4 + column)?.colorHex ?? "#2A2A2A")))
                                    .frame(width: side, height: side)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
