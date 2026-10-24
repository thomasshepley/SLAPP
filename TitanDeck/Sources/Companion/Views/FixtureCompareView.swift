// Companion/Views/FixtureCompareView.swift
import SwiftUI

/// Two fixtures side by side. The better figure in each row is highlighted.
struct FixtureCompareView: View {
    let library: FixtureLibrary
    let left: Fixture
    @State private var rightID: String?
    @AppStorage(CompanionSettings.unitsKey) private var unitSystem: UnitSystem = .metric
    @Environment(\.dismiss) private var dismiss

    private var units: CompanionUnits { CompanionUnits(system: unitSystem) }
    private var right: Fixture? { rightID.flatMap(library.fixture(id:)) }

    var body: some View {
        Form {
            Section {
                FixturePickerRow(library: library, fixtureID: $rightID, noneTitle: "Choose a fixture")
            } header: {
                Text("Compare \(left.model) with")
            }
            if let right {
                Section {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                        GridRow {
                            Text("")
                            Text(left.model).font(.headline)
                            Text(right.model).font(.headline)
                        }
                        Divider()
                        row("Output at 1 m", left.photometry(for: nil)?.luxAt1m, right.photometry(for: nil)?.luxAt1m,
                            higherIsBetter: true) { units.illuminance.text($0) }
                        row("Beam angle", left.beamAngle, right.beamAngle, higherIsBetter: nil) { "\($0.formatted())°" }
                        row("Power", left.powerW, right.powerW, higherIsBetter: false) { "\(Int($0)) W" }
                        row("Weight", left.weightKg, right.weightKg, higherIsBetter: false) { units.mass.text($0) }
                        row("CRI", left.colour?.cri, right.colour?.cri, higherIsBetter: true) { "\(Int($0))" }
                        row("TLCI", left.colour?.tlci, right.colour?.tlci, higherIsBetter: true) { "\(Int($0))" }
                        row("Lux per watt", efficiency(left), efficiency(right), higherIsBetter: true) { "\(Int($0))" }
                        GridRow {
                            Text("Modes").foregroundStyle(.secondary)
                            Text("\(left.modes.count) · \(left.footprintSummary)")
                            Text("\(right.modes.count) · \(right.footprintSummary)")
                        }
                    }
                    .monospacedDigit()
                }
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") { dismiss() }
            }
        }
    }

    private func efficiency(_ fixture: Fixture) -> Double? {
        guard let lux = fixture.photometry(for: nil)?.luxAt1m, let watts = fixture.powerW, watts > 0 else { return nil }
        return lux / watts
    }

    @ViewBuilder
    private func row(_ title: String, _ a: Double?, _ b: Double?, higherIsBetter: Bool?,
                     format: (Double) -> String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            cell(a, other: b, higherIsBetter: higherIsBetter, format: format)
            cell(b, other: a, higherIsBetter: higherIsBetter, format: format)
        }
    }

    @ViewBuilder
    private func cell(_ value: Double?, other: Double?, higherIsBetter: Bool?, format: (Double) -> String) -> some View {
        if let value {
            let wins: Bool = {
                guard let other, let higherIsBetter, value != other else { return false }
                return higherIsBetter ? value > other : value < other
            }()
            Text(format(value))
                .fontWeight(wins ? .semibold : .regular)
                .foregroundStyle(wins ? Color.green : Color.primary)
        } else {
            Text("-").foregroundStyle(.tertiary)
        }
    }
}
