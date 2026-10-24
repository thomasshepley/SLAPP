// Companion/Views/ColourToolView.swift
import SwiftUI

/// Colour temperature correction, gels, RGB <-> HSI, tunable white and
/// green/magenta correction.
struct ColourToolView: View {
    let library: FixtureLibrary
    @State private var sourceK: Double = 5600
    @State private var targetK: Double = 3200
    @State private var faderPercent: Double = 50
    @State private var minK: Double = 2700
    @State private var maxK: Double = 6500
    @State private var duv: Double = 0.0015
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

            ColourConverterSection()

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

            tintSection
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

    /// Green/magenta: a light can sit a bit green or pink of a true white.
    /// Colour meters show it as Duv; this says what it looks like and which
    /// gel cancels it.
    private var tintSection: some View {
        let fix = ColourMaths.tintCorrection(duv: duv)
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Meter reads (Duv)") {
                    TextField("Duv", value: $duv, format: .number.precision(.fractionLength(4)))
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(maxWidth: 110)
                }
                Slider(value: $duv, in: -0.012 ... 0.012, step: 0.0001) {
                    Text("Duv")
                } minimumValueLabel: {
                    Text("Magenta").font(.caption).foregroundStyle(.pink)
                } maximumValueLabel: {
                    Text("Green").font(.caption).foregroundStyle(.green)
                }
                .tint(duv > 0 ? Color.green : Color.pink)
            }

            ResultRow(title: "The light looks",
                      value: fix.looks == .neutral ? "Neutral"
                          : "\(fix.looks == .green ? "Green" : "Magenta")",
                      detail: fix.looks == .neutral ? "No correction needed" : "About \(fix.strength ?? "") too \(fix.looks == .green ? "green" : "magenta")",
                      tint: fix.looks == .green ? Color.green : fix.looks == .magenta ? Color.pink : Color.primary)

            if let gel = fix.gelName, let strength = fix.strength {
                ResultRow(title: "Correct with",
                          value: "\(strength) \(gel)",
                          detail: "LEE \(fix.leeNumber ?? "")\(fix.beyondFull ? " - and it's still more than that" : "")",
                          tint: gel == "Minus Green" ? Color.pink : Color.green)
                Label(fix.looks == .green
                      ? "On an LED fixture, turn its +/- green (tint) control towards magenta instead."
                      : "On an LED fixture, turn its +/- green (tint) control towards green instead.",
                      systemImage: "lightbulb.led")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Green / magenta (tint)")
        } footer: {
            Text("Duv is how far a light sits off true white: plus is green, minus is magenta. Colour meters (Sekonic C-800, Asensetek) show it. On camera it's the tint control. Gel strengths are approximate: about 0.0007 Duv per eighth.")
        }
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
