// Companion/Views/CompanionView.swift
import SwiftUI

/// The lighting companion: fixture library and on-set calculators. A sidebar
/// on iPad and iPhone Duo open, a single stack on iPhone.
struct CompanionView: View {
    @State private var selection: CompanionSection? = .fixtures
    @State private var fixturePath = NavigationPath()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState

    private let library = CompanionLibrary.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Library") {
                    sidebarRow(.fixtures, detail: "\(library.fixtures.count)")
                    sidebarRow(.gels, detail: "\(library.gels.count)")
                }
                Section("Tools") {
                    ForEach([CompanionSection.beam, .stops, .power, .colour, .flicker, .sun]) { sidebarRow($0) }
                }
                Section {
                    sidebarRow(.settings)
                }
            }
            .navigationTitle("Companion")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Send to PC", systemImage: "paperplane") { appState.showingFileDrop = true }
                }
            }
        } detail: {
            switch selection ?? .fixtures {
            case .fixtures:
                NavigationStack(path: $fixturePath) {
                    FixtureLibraryView(library: library)
                }
            case let section:
                NavigationStack {
                    tool(section)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func sidebarRow(_ section: CompanionSection, detail: String? = nil) -> some View {
        NavigationLink(value: section) {
            HStack(spacing: 12) {
                ToolIcon(symbol: section.symbol, tint: section.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                    if horizontalSizeClass == .compact {
                        Text(section.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func tool(_ section: CompanionSection) -> some View {
        switch section {
        case .fixtures: FixtureLibraryView(library: library)
        case .gels: GelLibraryView(library: library)
        case .beam: BeamToolView(library: library)
        case .stops: StopsToolView(library: library)
        case .power: PowerToolView(library: library)
        case .colour: ColourToolView(library: library)
        case .flicker: FlickerToolView(library: library)
        case .sun: SunToolView()
        case .settings: CompanionSettingsView()
        }
    }
}

/// Loads the bundled library once. It's several megabytes of DMX modes, so
/// the app warms it up in the background at launch rather than making the
/// first Companion tap wait.
enum CompanionLibrary {
    static let shared = FixtureLibrary.bundled()
    static let flicker = FlickerLibrary.bundled()

    static func warmUp() {
        Task.detached(priority: .utility) {
            _ = shared
            _ = flicker
        }
    }
}
