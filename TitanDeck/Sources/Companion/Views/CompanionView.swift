// Companion/Views/CompanionView.swift
import SwiftUI

/// The lighting companion: fixture library and on-set calculators. A sidebar
/// on iPad and iPhone Duo open, a single stack on iPhone.
struct CompanionView: View {
    @State private var selection: CompanionSection? = .fixtures
    @State private var fixturePath = NavigationPath()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let library = CompanionLibrary.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Library") {
                    sidebarRow(.fixtures, detail: "\(library.fixtures.count)")
                }
                Section("Tools") {
                    ForEach([CompanionSection.beam, .stops, .power, .colour, .camera, .sun]) { sidebarRow($0) }
                }
                Section {
                    sidebarRow(.settings)
                }
            }
            .navigationTitle("Companion")
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
        case .beam: BeamToolView(library: library)
        case .stops: StopsToolView(library: library)
        case .power: PowerToolView(library: library)
        case .colour: ColourToolView(library: library)
        case .camera: CameraToolView()
        case .sun: SunToolView()
        case .settings: CompanionSettingsView()
        }
    }
}

/// Loads the bundled library once, the first time the Companion opens.
enum CompanionLibrary {
    static let shared = FixtureLibrary.bundled()
}
