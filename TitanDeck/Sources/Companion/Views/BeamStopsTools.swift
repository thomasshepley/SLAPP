// Companion/Views/BeamStopsTools.swift
import Charts
import SwiftUI

/// Inverse square law and beam coverage, each with its reverse solve.
struct BeamToolView: View {
    let library: FixtureLibrary
    @State private var fixtureID: String?
    @State private var manualLux: Double = 10_000
    @State private var manualAngle: Double = 30
    @State private var distance: Double = 4
    @State private var targetLux: Double = 1000
    @State private var targetDiameter: Double = 3
    @AppStorage(CompanionSettings.unitsKey) private var unitSystem: UnitSystem = .metric

    init(library: FixtureLibrary, initialFixtureID: String? = nil) {
        self.library = library
        _fixtureID = State(initialValue: initialFixtureID)
    }

    private var units: CompanionUnits { CompanionUnits(system: unitSystem) }
    private var fixture: Fixture? { fixtureID.flatMap(library.fixture(id:)) }
    private var luxAt1m: Double { fixture?.photometry(for: nil)?.luxAt1m ?? manualLux }
    private var angle: Double { fixture?.beamAngle ?? manualAngle }

    var body: some View {
        Form {
            Section {
                FixturePickerRow(library: library, fixtureID: $fixtureID)
                if fixture == nil {
                    NumberField(title: "Output at 1 m", value: illuminanceBinding($manualLux),
                                unit: units.illuminance.unit, places: 0)
                    NumberField(title: "Beam angle", value: $manualAngle, unit: "°", places: 1)
                } else {
                    LabeledContent("Output at 1 m", value: units.illuminance.text(luxAt1m))
                    LabeledContent("Beam angle", value: "\(angle.formatted())°")
                }
            } header: {
                Text("Light")
            }

            Section {
                PhotometryCard(luxAt1m: luxAt1m, beamAngle: angle, distance: $distance, units: units)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                NumberField(title: "Target", value: illuminanceBinding($targetLux), unit: units.illuminance.unit, places: 0)
                ResultRow(title: "Place it at",
                          value: units.distance.text(Photometry.distance(forLux: targetLux, luxAt1m: luxAt1m), places: 2))
            } header: {
                Text("Distance for a light level")
            }

            Section {
                NumberField(title: "Cover a diameter of", value: distanceBinding($targetDiameter), unit: units.distance.unit)
                ResultRow(title: "Throw needed",
                          value: units.distance.text(Photometry.throwDistance(angle: angle, diameter: targetDiameter), places: 2))
                if let zoom = fixture?.beam?.zoomRangeDeg {
                    LabeledContent("Across the zoom (\(Int(zoom.minDeg))-\(Int(zoom.maxDeg))°)") {
                        Text("\(units.distance.text(Photometry.throwDistance(angle: zoom.maxDeg, diameter: targetDiameter))) - \(units.distance.text(Photometry.throwDistance(angle: zoom.minDeg, diameter: targetDiameter)))")
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Throw for a beam size")
            }
        }
        .navigationTitle(CompanionSection.beam.title)
    }

    /// Edits a canonical lux value in the display unit.
    private func illuminanceBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(get: { units.illuminance.display(value.wrappedValue) },
                set: { value.wrappedValue = units.illuminance.canonical($0) })
    }

    private func distanceBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(get: { units.distance.display(value.wrappedValue) },
                set: { value.wrappedValue = units.distance.canonical($0) })
    }
}

/// DMX for each stop up or down, following the fixture's dimming curve.
struct StopsToolView: View {
    let library: FixtureLibrary
    @State private var fixtureID: String?
    @State private var manualCurve: DimmingCurve.Kind = .linear
    @State private var manualLux: Double = 5000
    @State private var dmx: Double = 128
    @AppStorage(CompanionSettings.unitsKey) private var unitSystem: UnitSystem = .metric

    init(library: FixtureLibrary, initialFixtureID: String? = nil) {
        self.library = library
        _fixtureID = State(initialValue: initialFixtureID)
    }

    private var units: CompanionUnits { CompanionUnits(system: unitSystem) }
    private var fixture: Fixture? { fixtureID.flatMap(library.fixture(id:)) }
    private var curve: DimmingCurve { fixture?.photometry(for: nil)?.dimmingCurve ?? DimmingCurve(type: manualCurve) }
    private var luxAt1m: Double? { fixture == nil ? manualLux : fixture?.photometry(for: nil)?.luxAt1m }
    private var result: Stops.Result {
        Stops.compute(dmx: Int(dmx.rounded()), curve: curve, luxAt1m: luxAt1m, offsets: [-3, -2, -1, 1, 2, 3])
    }

    var body: some View {
        Form {
            Section {
                FixturePickerRow(library: library, fixtureID: $fixtureID)
                if fixture == nil {
                    Picker("Dimming curve", selection: $manualCurve) {
                        ForEach(DimmingCurve.Kind.allCases.filter { $0 != .measured }) { Text($0.title).tag($0) }
                    }
                    NumberField(title: "Output at 1 m",
                                value: Binding(get: { units.illuminance.display(manualLux) },
                                               set: { manualLux = units.illuminance.canonical($0) }),
                                unit: units.illuminance.unit, places: 0)
                } else {
                    LabeledContent("Dimming curve", value: curve.type.title)
                }
            } header: {
                Text("Light")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Now at")
                        Spacer()
                        Text("DMX \(result.currentDmx) · \(result.currentPercent.formatted())%")
                            .font(.headline.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                    Slider(value: $dmx, in: 0 ... 255, step: 1)
                }
                if let lux = result.currentLux {
                    LabeledContent("Output at 1 m", value: units.illuminance.text(lux))
                }
            } header: {
                Text("Current level")
            }

            Section {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Stops").foregroundStyle(.secondary)
                        Text("DMX").foregroundStyle(.secondary)
                        Text("Level").foregroundStyle(.secondary)
                        Text("")
                    }
                    .font(.caption.weight(.semibold))
                    ForEach(result.rows) { row in
                        GridRow {
                            Text(row.stops > 0 ? "+\(row.stops)" : "\(row.stops)")
                                .font(.headline)
                                .foregroundStyle(row.stops > 0 ? Color.orange : Color.indigo)
                            Text("\(row.dmx)").font(.title3.weight(.semibold))
                            Text("\(row.percent.formatted())%")
                            if row.clipped {
                                Label("Out of range", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("")
                            }
                        }
                        .monospacedDigit()
                    }
                }
                .animation(.snappy, value: result)
            } header: {
                Text("Stops")
            } footer: {
                Text("A stop doubles or halves the light. On non-linear fixtures the DMX change for one stop depends on where you start.")
            }

            Section("Dimming curve") {
                Chart {
                    ForEach(Array(stride(from: 0.0, through: 1.0, by: 0.02)), id: \.self) { x in
                        LineMark(x: .value("DMX", x * 255), y: .value("Output", Dimming.output(atDmx: x, curve: curve) * 100))
                            .foregroundStyle(.indigo)
                    }
                    PointMark(x: .value("DMX", Double(result.currentDmx)),
                              y: .value("Output", Dimming.output(atDmx: Double(result.currentDmx) / 255, curve: curve) * 100))
                        .foregroundStyle(.primary)
                        .symbolSize(90)
                    ForEach(result.rows.filter { !$0.clipped }) { row in
                        PointMark(x: .value("DMX", Double(row.dmx)), y: .value("Output", min(1, row.outputFraction) * 100))
                            .foregroundStyle(row.stops > 0 ? Color.orange : Color.indigo)
                            .annotation(position: .top) {
                                Text(row.stops > 0 ? "+\(row.stops)" : "\(row.stops)").font(.caption2.weight(.bold))
                            }
                    }
                }
                .chartXScale(domain: 0.0 ... 255.0)
                .chartYScale(domain: 0.0 ... 100.0)
                .chartXAxisLabel("DMX")
                .chartYAxisLabel("Output %")
                .frame(height: 220)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(CompanionSection.stops.title)
    }
}
