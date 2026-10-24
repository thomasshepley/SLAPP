// Companion/Views/FixtureLibraryView.swift
import SwiftUI

/// Every fixture, grouped by manufacturer, searchable and filterable by type.
struct FixtureLibraryView: View {
    let library: FixtureLibrary
    @State private var search = ""
    @State private var category: String?
    @State private var manufacturer: String?

    private var results: [Fixture] {
        library.search(search, category: category, manufacturer: manufacturer)
    }

    private var groups: [(manufacturer: String, fixtures: [Fixture])] {
        Dictionary(grouping: results, by: \.manufacturer)
            .map { ($0.key, $0.value) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
    }

    var body: some View {
        List {
            if category != nil || manufacturer != nil {
                Section {
                    filterChips
                }
            }
            ForEach(groups, id: \.manufacturer) { group in
                Section {
                    ForEach(group.fixtures) { fixture in
                        NavigationLink(value: fixture) {
                            FixtureRow(fixture: fixture)
                        }
                    }
                } header: {
                    Text(group.manufacturer)
                } footer: {
                    if group.manufacturer == groups.last?.manufacturer {
                        Text("\(results.count) of \(library.fixtures.count) fixtures")
                    }
                }
            }
        }
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Model, manufacturer or type")
        .navigationTitle("Fixtures")
        .navigationDestination(for: Fixture.self) { fixture in
            FixtureDetailView(fixture: fixture, library: library)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Type", selection: $category) {
                        Text("All types").tag(String?.none)
                        ForEach(library.categories, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    Picker("Manufacturer", selection: $manufacturer) {
                        Text("All manufacturers").tag(String?.none)
                        ForEach(library.manufacturers, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                } label: {
                    Label("Filter", systemImage: category == nil && manufacturer == nil
                          ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
    }

    private var filterChips: some View {
        HStack {
            if let category {
                chip(category) { self.category = nil }
            }
            if let manufacturer {
                chip(manufacturer) { self.manufacturer = nil }
            }
            Spacer()
        }
    }

    private func chip(_ text: String, clear: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { clear() } }) {
            Label(text, systemImage: "xmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.callout.weight(.medium))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }
}

/// One fixture: headline specs, DMX modes as a channel chart, and a live
/// photometry readout.
struct FixtureDetailView: View {
    let fixture: Fixture
    let library: FixtureLibrary
    @AppStorage(CompanionSettings.unitsKey) private var unitSystem: UnitSystem = .metric
    @State private var modeName: String = ""
    @State private var distance: Double = 3
    @State private var comparing = false

    private var units: CompanionUnits { CompanionUnits(system: unitSystem) }
    private var mode: FixtureMode? { fixture.modes.first { $0.name == modeName } ?? fixture.modes.first }
    private var photometry: FixturePhotometry? { fixture.photometry(for: mode?.name) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                specGrid
                modeCard
                if let lux = photometry?.luxAt1m {
                    PhotometryCard(luxAt1m: lux, beamAngle: fixture.beamAngle, distance: $distance, units: units)
                }
                toolLinks
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(fixture.model)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Compare", systemImage: "rectangle.split.2x1") { comparing = true }
            }
        }
        .sheet(isPresented: $comparing) {
            NavigationStack {
                FixtureCompareView(library: library, left: fixture)
            }
        }
        .onAppear { if modeName.isEmpty { modeName = fixture.modes.first?.name ?? "" } }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            ToolIcon(symbol: fixture.symbol, tint: .yellow, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(fixture.manufacturer)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(fixture.model)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if let category = fixture.category {
                    Text(category)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.yellow.opacity(0.2), in: .capsule)
                }
            }
        }
    }

    private var specGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            if let lux = photometry?.luxAt1m {
                StatTile(title: "Output at 1 m", value: units.illuminance.text(lux), symbol: "sun.max.fill", tint: .yellow)
            }
            if let angle = fixture.beamAngle {
                let zoom = fixture.beam?.zoomRangeDeg.map { " (\(Int($0.minDeg))-\(Int($0.maxDeg))°)" } ?? ""
                StatTile(title: "Beam angle", value: "\(angle.formatted())°\(zoom)", symbol: "light.beacon.max", tint: .orange)
            }
            if let watts = mode?.powerW ?? fixture.powerW {
                StatTile(title: "Power", value: "\(Int(watts)) W", symbol: "bolt.fill", tint: .red)
            }
            if let kg = fixture.weightKg {
                StatTile(title: "Weight", value: units.mass.text(kg), symbol: "scalemass.fill", tint: .gray)
            }
            if let range = fixture.colour?.cctRange {
                StatTile(title: "CCT", value: "\(Int(range.minK))-\(Int(range.maxK)) K", symbol: "thermometer.medium", tint: .blue)
            } else if let native = fixture.colour?.nativeCct {
                StatTile(title: "CCT", value: "\(Int(native)) K", symbol: "thermometer.medium", tint: .blue)
            }
            if let cri = fixture.colour?.cri {
                let tlci = fixture.colour?.tlci.map { " · TLCI \(Int($0))" } ?? ""
                StatTile(title: "Colour quality", value: "CRI \(Int(cri))\(tlci)", symbol: "eye.fill", tint: .pink)
            }
            if let curve = photometry?.dimmingCurve {
                StatTile(title: "Dimming", value: curve.type.title, symbol: "slider.horizontal.below.sun.max", tint: .indigo)
            }
        }
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DMX modes")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("Mode", selection: $modeName) {
                    ForEach(fixture.modes) { mode in
                        Text("\(mode.name) (\(mode.channelCount) ch)").tag(mode.name)
                    }
                }
                .pickerStyle(.menu)
            }
            if let mode {
                DmxChart(mode: mode)
            }
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 20))
    }

    private var toolLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Open in")
                .font(.title3.weight(.semibold))
            HStack(spacing: 12) {
                NavigationLink {
                    BeamToolView(library: library, initialFixtureID: fixture.id)
                } label: {
                    Label("Beam & Photometry", systemImage: CompanionSection.beam.symbol)
                }
                NavigationLink {
                    StopsToolView(library: library, initialFixtureID: fixture.id)
                } label: {
                    Label("Stops", systemImage: CompanionSection.stops.symbol)
                }
                NavigationLink {
                    PowerToolView(library: library, initialFixtureID: fixture.id)
                } label: {
                    Label("Power", systemImage: CompanionSection.power.symbol)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

/// A mode's channels as tiles, colour-coded by what they control. 16-bit
/// channels span two slots.
struct DmxChart: View {
    let mode: FixtureMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(slots, id: \.number) { slot in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(slot.number)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(slot.colour)
                        Text(slot.label)
                            .font(.caption.weight(.medium))
                            .lineLimit(2, reservesSpace: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(slot.colour.opacity(slot.isFine ? 0.08 : 0.16), in: .rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(slot.colour.opacity(0.35), lineWidth: 1)
                    }
                }
            }
            HStack(spacing: 14) {
                ForEach(families, id: \.rawValue) { family in
                    Label(family.rawValue.capitalized, systemImage: "circle.fill")
                        .foregroundStyle(family.colour)
                }
            }
            .font(.caption2)
            .labelStyle(.titleAndIcon)
        }
    }

    private struct Slot {
        let number: Int
        let label: String
        let colour: Color
        let isFine: Bool
    }

    private var slots: [Slot] {
        var result: [Slot] = []
        for channel in mode.channels.sorted(by: { $0.offset < $1.offset }) {
            for part in 0 ..< channel.slotCount {
                let label = part == 0 ? channel.label : "\(channel.label) \(part == 1 ? "fine" : "ultra")"
                result.append(Slot(number: channel.offset + part + 1, label: label,
                                   colour: channel.attribute.family.colour, isFine: part > 0))
            }
        }
        // Slots the mode reserves but doesn't describe.
        let used = Set(result.map(\.number))
        for number in 1 ... max(1, mode.channelCount) where !used.contains(number) {
            result.append(Slot(number: number, label: "-", colour: .gray, isFine: true))
        }
        return result.sorted { $0.number < $1.number }
    }

    private var families: [ChannelAttribute.Family] {
        var seen: [ChannelAttribute.Family] = []
        for channel in mode.channels where !seen.contains(channel.attribute.family) {
            seen.append(channel.attribute.family)
        }
        return seen
    }
}
