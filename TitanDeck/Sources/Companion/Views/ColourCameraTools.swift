// Companion/Views/ColourCameraTools.swift
import SwiftUI

/// Colour temperature correction, gels, RGB to HSI, tunable white and tint.
struct ColourToolView: View {
    let library: FixtureLibrary
    @State private var sourceK: Double = 5600
    @State private var targetK: Double = 3200
    @State private var pickedColour: Color = .init(red: 0.15, green: 0.7, blue: 0.62)
    @State private var faderPercent: Double = 50
    @State private var minK: Double = 2700
    @State private var maxK: Double = 6500
    @State private var duv: Double = 0.002
    @State private var gelSearch = ""

    private var suggestion: ColourMaths.GelSuggestion { ColourMaths.suggestGel(from: sourceK, to: targetK) }

    var body: some View {
        Form {
            Section {
                kelvinSlider("From", value: $sourceK)
                kelvinSlider("To", value: $targetK)
                ResultRow(title: "Shift needed",
                          value: "\(Int(ColourMaths.correctionShift(from: sourceK, to: targetK).rounded())) mired",
                          detail: ColourMaths.correctionShift(from: sourceK, to: targetK) > 0 ? "warmer (CTO)" : "cooler (CTB)")
                ResultRow(title: "Nearest gel",
                          value: suggestion.family == .none ? "None needed" : "\(suggestion.strength) \(suggestion.family.rawValue)",
                          detail: suggestion.family == .none ? nil : "\(Int(suggestion.residual)) mired left over",
                          tint: suggestion.family == .cto ? .orange : suggestion.family == .ctb ? .blue : .green)
            } header: {
                Text("CTO / CTB correction")
            }

            Section {
                ForEach(gels) { gel in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: Double(gel.swatchRgb.r) / 255, green: Double(gel.swatchRgb.g) / 255,
                                        blue: Double(gel.swatchRgb.b) / 255))
                            .frame(width: 34, height: 34)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(gel.manufacturer) \(gel.number)").font(.body.weight(.medium))
                            Text(gel.name).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let shift = gel.miredShift {
                            Text("\(shift > 0 ? "+" : "")\(Int(shift))")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(shift > 0 ? Color.orange : Color.blue)
                        }
                    }
                }
                TextField("Search gels", text: $gelSearch)
            } header: {
                Text("Gels")
            } footer: {
                Text("Mired shift: + warms, - cools. Swatches are approximate.")
            }

            Section {
                ColorPicker("Colour", selection: $pickedColour, supportsOpacity: false)
                let rgb = rgbValue
                let hsi = ColourMaths.hsi(from: rgb)
                LabeledContent("RGB", value: "\(rgb.r), \(rgb.g), \(rgb.b)").monospacedDigit()
                LabeledContent("Hue", value: "\(hsi.h.formatted())°").monospacedDigit()
                LabeledContent("Saturation", value: "\(Int((hsi.s * 100).rounded()))%").monospacedDigit()
                LabeledContent("Intensity", value: "\(Int((hsi.i * 100).rounded()))%").monospacedDigit()
            } header: {
                Text("RGB to HSI")
            }

            Section {
                NumberField(title: "Warmest", value: $minK, unit: "K", places: 0)
                NumberField(title: "Coolest", value: $maxK, unit: "K", places: 0)
                VStack(alignment: .leading) {
                    LabeledContent("Fader \(Int(faderPercent))%") {
                        Text("\(Int(ColourMaths.cct(percent: faderPercent, minK: minK, maxK: maxK))) K")
                            .font(.headline.monospacedDigit())
                    }
                    Slider(value: $faderPercent, in: 0 ... 100, step: 1)
                        .tint(Color(kelvin: ColourMaths.cct(percent: faderPercent, minK: minK, maxK: maxK)))
                }
            } header: {
                Text("Tunable white")
            } footer: {
                Text("Interpolated in mired, which is how most tunable fixtures feel on the fader.")
            }

            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Duv", value: duv.formatted(.number.precision(.fractionLength(4))))
                    Slider(value: $duv, in: -0.01 ... 0.01, step: 0.0001)
                }
                let reading = ColourMaths.tint(duv: duv)
                ResultRow(title: "Reads as",
                          value: reading.direction == .neutral ? "Neutral" : "\(reading.direction.rawValue), \(reading.ccEighths)/8 CC",
                          tint: reading.direction == .green ? .green : reading.direction == .magenta ? .pink : .primary)
            } header: {
                Text("Tint")
            } footer: {
                Text("About 0.0007 Duv is one eighth of plus/minus green.")
            }
        }
        .navigationTitle(CompanionSection.colour.title)
    }

    private var gels: [Gel] {
        let words = gelSearch.lowercased().split(separator: " ")
        return library.gels.filter { gel in
            let text = "\(gel.manufacturer) \(gel.number) \(gel.name)".lowercased()
            return words.allSatisfy { text.contains($0) }
        }
    }

    private var rgbValue: RGB {
        let resolved = pickedColour.resolve(in: EnvironmentValues())
        func byte(_ v: Float) -> Int { Int((min(1, max(0, Double(v))) * 255).rounded()) }
        return RGB(r: byte(resolved.red), g: byte(resolved.green), b: byte(resolved.blue))
    }

    private func kelvinSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title) {
                Text("\(Int(value.wrappedValue)) K").font(.headline.monospacedDigit())
            }
            Slider(value: value, in: 2000 ... 10_000, step: 50)
                .tint(Color(kelvin: value.wrappedValue))
        }
    }
}

extension Color {
    /// An approximate display colour for a colour temperature (Tanner Helland's fit).
    init(kelvin: Double) {
        let t = kelvin / 100
        let r = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let g = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let b = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
        func unit(_ v: Double) -> Double { min(255, max(0, v)) / 255 }
        self.init(red: unit(r), green: unit(g), blue: unit(b))
    }
}

/// Exposure from a lux reading, flicker-safe shutters and ND stacks.
struct CameraToolView: View {
    @AppStorage(CompanionSettings.mainsHzKey) private var mainsHz: Int = 50
    @State private var lux: Double = 2000
    @State private var iso: Double = 800
    @State private var shutter: Double = 50
    @State private var ndSelection: Set<Double> = []
    @State private var stopsWanted: Double = 3

    private static let isos: [Double] = [100, 200, 400, 640, 800, 1280, 1600, 3200, 6400]
    private static let shutters: [Double] = [24, 25, 30, 48, 50, 60, 96, 100, 120, 125, 200, 250, 500]
    private static let nds: [Double] = [0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1]

    var body: some View {
        Form {
            Section {
                NumberField(title: "Incident reading", value: $lux, unit: "lux", places: 0)
                Picker("ISO", selection: $iso) {
                    ForEach(Self.isos, id: \.self) { Text("\(Int($0))").tag($0) }
                }
                Picker("Shutter", selection: $shutter) {
                    ForEach(Self.shutters, id: \.self) { Text("1/\(Int($0))").tag($0) }
                }
                let aperture = Exposure.aperture(lux: lux, iso: iso, shutter: shutter)
                ResultRow(title: "Aperture", value: "f/\(aperture.nearestStop.formatted())",
                          detail: "exactly f/\(aperture.exact.formatted()) · EV100 \(Exposure.ev100(lux: lux).formatted(.number.precision(.fractionLength(1))))")
            } header: {
                Text("Exposure")
            } footer: {
                Text("Incident meter convention (C = 250). Use it as a starting point, not a light meter.")
            }

            Section {
                Picker("Mains", selection: $mainsHz) {
                    Text("50 Hz").tag(50)
                    Text("60 Hz").tag(60)
                }
                .pickerStyle(.segmented)
                let check = Exposure.checkFlicker(shutter: shutter, mainsHz: mainsHz)
                ResultRow(title: "1/\(Int(shutter)) at \(mainsHz) Hz",
                          value: check.safe ? "Flicker safe" : "May flicker",
                          detail: check.safe ? nil : "Nearest safe: \(check.nearestSafe.map { "1/\($0)" }.joined(separator: " or "))",
                          tint: check.safe ? .green : .orange)
            } header: {
                Text("Flicker")
            } footer: {
                Text("For lamps that pulse with the mains (tungsten on a dimmer, older HMI and fluorescents). Safe shutters span whole half-cycles. 180° shutter: twice the frame rate.")
            }

            Section {
                ForEach(Self.nds, id: \.self) { nd in
                    Toggle(isOn: Binding(get: { ndSelection.contains(nd) },
                                         set: { if $0 { ndSelection.insert(nd) } else { ndSelection.remove(nd) } })) {
                        Text("ND \(nd.formatted())  ·  \(Exposure.stops(ndDensity: nd).formatted(.number.precision(.fractionLength(0))) ) stop\(nd > 0.3 ? "s" : "")")
                    }
                }
                let stack = Exposure.stack(densities: Array(ndSelection))
                ResultRow(title: "Stack", value: "\(stack.stops.formatted()) stops", detail: "ND \(stack.density.formatted())")
            } header: {
                Text("ND stack")
            }

            Section {
                Stepper("Lose \(stopsWanted.formatted()) stops", value: $stopsWanted, in: 0.5 ... 10, step: 0.5)
                ResultRow(title: "Use", value: "ND \(Exposure.ndDensity(stops: stopsWanted).formatted(.number.precision(.fractionLength(1))))",
                          detail: "ND\(Int(pow(2, stopsWanted).rounded())) in filter-factor terms")
            } header: {
                Text("Stops to ND")
            }
        }
        .navigationTitle(CompanionSection.camera.title)
    }
}
