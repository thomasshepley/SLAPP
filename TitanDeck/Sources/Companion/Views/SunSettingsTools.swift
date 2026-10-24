// Companion/Views/SunSettingsTools.swift
import Charts
import SwiftUI

/// Golden and blue hour for a place and date, the sun's position, and gobo
/// rotation from tempo.
struct SunToolView: View {
    @AppStorage("companion.sun.latitude") private var latitude: Double = 51.5074
    @AppStorage("companion.sun.longitude") private var longitude: Double = -0.1278
    @State private var date = Date()
    @State private var bpm: Double = 120
    @State private var goboMode: GoboSync.Mode = .beat
    @State private var beatsPerBar = 4

    /// The device's UTC offset on the chosen date, so BST/GMT follows the calendar.
    private var utcOffsetHours: Double { Double(TimeZone.current.secondsFromGMT(for: date)) / 3600 }
    private var location: Sun.Location { Sun.Location(latitude: latitude, longitude: longitude, utcOffsetHours: utcOffsetHours) }
    private var times: Sun.Times { Sun.times(on: date, at: location) }
    private var position: Sun.Position { Sun.position(at: date, location: location) }

    var body: some View {
        Form {
            Section {
                DatePicker("Date and time", selection: $date)
                NumberField(title: "Latitude", value: $latitude, unit: "°", places: 4, allowsNegative: true)
                NumberField(title: "Longitude", value: $longitude, unit: "°", places: 4, allowsNegative: true)
            } header: {
                Text("Where and when")
            } footer: {
                Text("Times are in this device's time zone. West and south are negative.")
            }

            Section {
                dayChart
                    .frame(height: 70)
                    .padding(.vertical, 6)
                timeRow("Sunrise", times.sunrise, symbol: "sunrise.fill", tint: .orange)
                windowRow("Golden hour (morning)", times.goldenMorning, tint: .yellow)
                windowRow("Golden hour (evening)", times.goldenEvening, tint: .yellow)
                timeRow("Sunset", times.sunset, symbol: "sunset.fill", tint: .orange)
                windowRow("Blue hour (morning)", times.blueMorning, tint: .blue)
                windowRow("Blue hour (evening)", times.blueEvening, tint: .blue)
            } header: {
                Text("The day")
            }

            Section {
                HStack(spacing: 12) {
                    StatTile(title: "Bearing", value: "\(Int(position.azimuth.rounded()))° \(compass(position.azimuth))",
                             symbol: "location.north.line.fill", tint: .orange)
                    StatTile(title: "Elevation", value: "\(Int(position.elevation.rounded()))°",
                             symbol: position.elevation > 0 ? "sun.max.fill" : "moon.fill",
                             tint: position.elevation > 0 ? .yellow : .indigo)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Sun at \(date.formatted(date: .omitted, time: .shortened))")
            }

            Section {
                Picker("Rotation", selection: $goboMode) {
                    ForEach(GoboSync.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                NumberField(title: "Tempo", value: $bpm, unit: "BPM", places: 1)
                if goboMode == .bar {
                    Stepper("\(beatsPerBar) beats to a bar", value: $beatsPerBar, in: 2 ... 12)
                }
                ResultRow(title: "Gobo speed", value: "\(GoboSync.rpm(bpm: bpm, mode: goboMode, beatsPerBar: beatsPerBar).formatted()) RPM")
            } header: {
                Text("Gobo sync")
            }
        }
        .navigationTitle(CompanionSection.sun.title)
    }

    private func clock(_ minutes: Double) -> String {
        let start = Calendar.current.startOfDay(for: date)
        return start.addingTimeInterval(minutes * 60).formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private func timeRow(_ title: String, _ minutes: Double?, symbol: String, tint: Color) -> some View {
        LabeledContent {
            Text(minutes.map(clock) ?? "None today").monospacedDigit()
        } label: {
            Label(title, systemImage: symbol).foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private func windowRow(_ title: String, _ window: Sun.Window?, tint: Color) -> some View {
        LabeledContent {
            Text(window.map { "\(clock($0.start)) - \(clock($0.end))" } ?? "None today").monospacedDigit()
        } label: {
            Label(title, systemImage: "circle.fill").foregroundStyle(tint)
        }
    }

    /// Night, blue, golden and daylight bands across 24 hours.
    private var dayChart: some View {
        var bands: [(name: String, start: Double, end: Double, colour: Color)] = []
        if let rise = times.sunrise, let set = times.sunset {
            bands.append(("Day", rise, set, .cyan.opacity(0.35)))
        }
        for (name, window, colour) in [("Blue", times.blueMorning, Color.blue), ("Blue", times.blueEvening, .blue),
                                        ("Golden", times.goldenMorning, .yellow), ("Golden", times.goldenEvening, .yellow)] {
            if let window { bands.append((name, min(window.start, window.end), max(window.start, window.end), colour)) }
        }
        let now = Calendar.current.dateComponents([.hour, .minute], from: date)
        let nowMinutes = Double((now.hour ?? 0) * 60 + (now.minute ?? 0))
        return Chart {
            RectangleMark(xStart: .value("Start", 0.0), xEnd: .value("End", 1440.0))
                .foregroundStyle(.indigo.opacity(0.25))
            ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                RectangleMark(xStart: .value("Start", band.start), xEnd: .value("End", band.end))
                    .foregroundStyle(band.colour)
            }
            RuleMark(x: .value("Now", nowMinutes))
                .foregroundStyle(.primary)
                .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXScale(domain: 0.0 ... 1440.0)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0.0, through: 1440.0, by: 180.0))) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) { Text("\(Int(minutes) / 60):00") }
                }
            }
        }
        .chartYAxis(.hidden)
    }

    private func compass(_ bearing: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return points[Int((bearing / 45).rounded()) % 8]
    }
}

/// Units, mains frequency and supply voltage used across the tools.
struct CompanionSettingsView: View {
    @AppStorage(CompanionSettings.unitsKey) private var unitSystem: UnitSystem = .metric
    @AppStorage(CompanionSettings.mainsHzKey) private var mainsHz: Int = 50
    @AppStorage(CompanionSettings.voltageKey) private var voltage: Double = 230

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Metres, lux and kilograms, or feet, footcandles and pounds.")
            }
            Section {
                Picker("Mains frequency", selection: $mainsHz) {
                    Text("50 Hz (UK, Europe)").tag(50)
                    Text("60 Hz (US, Japan west)").tag(60)
                }
                Picker("Supply voltage", selection: $voltage) {
                    Text("230 V").tag(230.0)
                    Text("240 V").tag(240.0)
                    Text("120 V").tag(120.0)
                    Text("110 V").tag(110.0)
                }
            } header: {
                Text("Mains")
            } footer: {
                Text("Used by the flicker check and the power budget.")
            }
        }
        .navigationTitle(CompanionSection.settings.title)
    }
}
