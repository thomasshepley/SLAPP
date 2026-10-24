// Companion/Views/CompanionComponents.swift
import SwiftUI

/// The Companion's sections, in sidebar order.
enum CompanionSection: String, CaseIterable, Identifiable, Hashable {
    case fixtures, beam, stops, power, colour, camera, sun, settings

    var id: Self { self }

    var title: String {
        switch self {
        case .fixtures: return "Fixtures"
        case .beam: return "Beam & Photometry"
        case .stops: return "Stops"
        case .power: return "Power & Cable"
        case .colour: return "Colour & Gels"
        case .camera: return "Camera"
        case .sun: return "Sun & Sync"
        case .settings: return "Units & Mains"
        }
    }

    var symbol: String {
        switch self {
        case .fixtures: return "lightbulb.2.fill"
        case .beam: return "light.beacon.max.fill"
        case .stops: return "plusminus.circle.fill"
        case .power: return "bolt.fill"
        case .colour: return "paintpalette.fill"
        case .camera: return "camera.aperture"
        case .sun: return "sun.horizon.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .fixtures: return .yellow
        case .beam: return .orange
        case .stops: return .indigo
        case .power: return .red
        case .colour: return .pink
        case .camera: return .teal
        case .sun: return .blue
        case .settings: return .gray
        }
    }

    var subtitle: String {
        switch self {
        case .fixtures: return "Specs, DMX modes and photometry"
        case .beam: return "Inverse square law and beam coverage"
        case .stops: return "DMX for each stop up or down"
        case .power: return "Load, distro and cable sizing"
        case .colour: return "Mired, CTO/CTB, HSI and tint"
        case .camera: return "Exposure, flicker and ND"
        case .sun: return "Golden hour, blue hour and gobo tempo"
        case .settings: return "Metric or imperial, 50 or 60 Hz"
        }
    }
}

/// A Settings-style icon: a white symbol on a rounded, coloured square.
struct ToolIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.24))
    }
}

/// A headline number with a caption, for spec and result grids.
struct StatTile: View {
    let title: String
    let value: String
    var symbol: String?
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                if let symbol { Image(systemName: symbol).foregroundStyle(tint) }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.quaternary, in: .rect(cornerRadius: 14))
    }
}

/// A big answer at the bottom of a tool section.
struct ResultRow: View {
    let title: String
    let value: String
    var detail: String?
    var tint: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.snappy, value: value)
    }
}

/// A labelled number entry with its unit, e.g. "Distance  [ 4.5 ] m".
struct NumberField: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""
    var places: Int = 2
    /// The decimal pad has no minus key, so signed values get the full keyboard.
    var allowsNegative = false

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0 ... places)))
                    .keyboardType(allowsNegative ? .numbersAndPunctuation : .decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(maxWidth: 140)
                if !unit.isEmpty {
                    Text(unit)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Picks a fixture from the library, or none for manual entry.
struct FixturePickerRow: View {
    let library: FixtureLibrary
    @Binding var fixtureID: String?
    var noneTitle = "Manual entry"

    var body: some View {
        NavigationLink {
            FixtureChooser(library: library, fixtureID: $fixtureID, noneTitle: noneTitle)
        } label: {
            LabeledContent("Fixture") {
                Text(library.fixture(id: fixtureID ?? "")?.name ?? noneTitle)
                    .lineLimit(1)
            }
        }
    }
}

private struct FixtureChooser: View {
    let library: FixtureLibrary
    @Binding var fixtureID: String?
    let noneTitle: String
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if search.isEmpty {
                Button {
                    fixtureID = nil
                    dismiss()
                } label: {
                    HStack {
                        Label(noneTitle, systemImage: "slider.horizontal.3")
                        Spacer()
                        if fixtureID == nil { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
            }
            ForEach(library.search(search)) { fixture in
                Button {
                    fixtureID = fixture.id
                    dismiss()
                } label: {
                    HStack {
                        FixtureRow(fixture: fixture)
                        if fixture.id == fixtureID { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .searchable(text: $search, prompt: "Search \(library.fixtures.count) fixtures")
        .navigationTitle("Choose Fixture")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ChannelAttribute.Family {
    var colour: Color {
        switch self {
        case .intensity: return .yellow
        case .colour: return .pink
        case .white: return .orange
        case .position: return .blue
        case .beam: return .purple
        case .control: return .gray
        }
    }
}

extension Fixture {
    /// A symbol for the fixture's category.
    var symbol: String {
        let category = (category ?? "").lowercased()
        if category.contains("tube") || category.contains("batten") || category.contains("pixel") { return "light.strip.2.fill" }
        if category.contains("moving") || category.contains("spot") || category.contains("profile") { return "light.beacon.max.fill" }
        if category.contains("fresnel") || category.contains("par") { return "lamp.ceiling.fill" }
        if category.contains("panel") || category.contains("soft") || category.contains("mat") { return "rectangle.inset.filled" }
        if category.contains("cob") || category.contains("bulb") || category.contains("puck") { return "lightbulb.led.fill" }
        return "lightbulb.fill"
    }
}

/// One fixture in a list: icon, model, manufacturer and key numbers.
struct FixtureRow: View {
    let fixture: Fixture

    var body: some View {
        HStack(spacing: 12) {
            ToolIcon(symbol: fixture.symbol, tint: .yellow, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(fixture.model)
                    .font(.body.weight(.medium))
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    private var details: String {
        var parts = [fixture.manufacturer, fixture.footprintSummary]
        if let watts = fixture.powerW { parts.append("\(Int(watts)) W") }
        return parts.joined(separator: " · ")
    }
}
