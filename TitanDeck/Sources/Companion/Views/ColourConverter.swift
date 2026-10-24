// Companion/Views/ColourConverter.swift
import SwiftUI

/// Two-way RGB <-> HSI: enter either, with sliders or by typing, and read the
/// other live. RGB is shown 0-255 (DMX), as percentages (how Titan shows
/// colour attributes) and as hex.
struct ColourConverterSection: View {
    let library: FixtureLibrary
    enum Input: String, CaseIterable, Identifiable {
        case rgb = "RGB"
        case hsi = "HSI"
        var id: Self { self }
    }

    @State private var input: Input = .rgb
    @State private var red: Double = 38
    @State private var green: Double = 179
    @State private var blue: Double = 158
    @State private var hue: Double = 172
    @State private var saturation: Double = 56
    @State private var intensity: Double = 49
    @State private var hexText = ""
    @FocusState private var hexFocused: Bool

    private var rgb: RGB {
        switch input {
        case .rgb: RGB(r: Int(red.rounded()), g: Int(green.rounded()), b: Int(blue.rounded()))
        case .hsi: ColourMaths.rgb(from: hsiInput)
        }
    }

    private var hsiInput: HSI { HSI(h: hue, s: saturation / 100, i: intensity / 100) }
    private var hsi: HSI { input == .hsi ? hsiInput : ColourMaths.hsi(from: rgb) }
    private var clipped: Bool { input == .hsi && ColourMaths.isClipped(hsiInput) }
    private var swatch: Color { Color(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255) }

    var body: some View {
        Section {
            swatchCard
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            Picker("Enter", selection: $input) {
                ForEach(Input.allCases) { Text("Enter \($0.rawValue)").tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: input) { old, new in sync(from: old, to: new) }

            switch input {
            case .rgb:
                ChannelRow(title: "Red", value: $red, range: 0 ... 255, unit: "",
                           track: [.black, .red])
                ChannelRow(title: "Green", value: $green, range: 0 ... 255, unit: "",
                           track: [.black, .green])
                ChannelRow(title: "Blue", value: $blue, range: 0 ... 255, unit: "",
                           track: [.black, .blue])
                LabeledContent("Hex") {
                    TextField("#26B39E", text: $hexText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .monospaced()
                        .focused($hexFocused)
                        .onSubmit(applyHex)
                        .onChange(of: hexFocused) { _, focused in if !focused { applyHex() } }
                }
            case .hsi:
                ChannelRow(title: "Hue", value: $hue, range: 0 ... 360, unit: "°",
                           track: stride(from: 0.0, through: 1.0, by: 1.0 / 6).map { Color(hue: $0, saturation: 1, brightness: 1) })
                ChannelRow(title: "Saturation", value: $saturation, range: 0 ... 100, unit: "%",
                           track: [.white, Color(hue: hue / 360, saturation: 1, brightness: 1)])
                ChannelRow(title: "Intensity", value: $intensity, range: 0 ... 100, unit: "%",
                           track: [.black, Color(hue: hue / 360, saturation: saturation / 100, brightness: 1)])
            }

            ColorPicker(selection: pickerBinding, supportsOpacity: false) {
                Label("Pick a colour", systemImage: "eyedropper")
            }
            nearestGels
        } header: {
            Text("RGB and HSI")
        } footer: {
            Text(clipped
                 ? "That saturation can't be made at this intensity, so the RGB shown is as close as the LEDs get. Lower the intensity to see the full colour."
                 : "HSI is hue (the colour, 0-360°), saturation (how pure, 0% is white) and intensity (how bright). Titan's colour attributes show RGB as percentages.")
        }
        .onAppear { if hexText.isEmpty { hexText = ColourMaths.hex(rgb) } }
        .onChange(of: rgb) { _, newValue in if !hexFocused { hexText = ColourMaths.hex(newValue) } }
    }

    /// The gels that look most like this colour, across all ranges.
    @ViewBuilder
    private var nearestGels: some View {
        let matches = library.nearestGels(to: rgb, count: 4)
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nearest gels").font(.subheadline.weight(.semibold))
                HStack(spacing: 10) {
                    ForEach(matches) { gel in
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(gel: gel))
                                .frame(height: 34)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                            Text(gel.displayNumber).font(.caption2.weight(.bold)).lineLimit(1)
                            Text(gel.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var swatchCard: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18)
                .fill(swatch)
                .frame(width: 96, height: 96)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.separator))
                .shadow(color: swatch.opacity(0.5), radius: 12, y: 4)
                .animation(.snappy, value: rgb)
            VStack(alignment: .leading, spacing: 8) {
                readout(title: "RGB", value: "\(rgb.r)  \(rgb.g)  \(rgb.b)", detail: percentages)
                readout(title: "HSI", value: "\(Int(hsi.h.rounded()))°  \(Int((hsi.s * 100).rounded()))%  \(Int((hsi.i * 100).rounded()))%",
                        detail: "hue  sat  int")
                Text(ColourMaths.hex(rgb))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
    }

    private var percentages: String {
        [rgb.r, rgb.g, rgb.b].map { "\(Int((Double($0) / 255 * 100).rounded()))%" }.joined(separator: "  ")
    }

    private func readout(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            Text(detail)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .padding(.leading, 38)
        }
    }

    /// Switching what you type in: carry the colour across so nothing jumps.
    private func sync(from old: Input, to new: Input) {
        guard old != new else { return }
        switch new {
        case .hsi:
            let converted = ColourMaths.hsi(from: RGB(r: Int(red.rounded()), g: Int(green.rounded()), b: Int(blue.rounded())))
            if converted.s > 0.005 { hue = converted.h }   // grey has no hue; keep the last one
            saturation = (converted.s * 100).rounded()
            intensity = (converted.i * 100).rounded()
        case .rgb:
            let converted = ColourMaths.rgb(from: hsiInput)
            red = Double(converted.r)
            green = Double(converted.g)
            blue = Double(converted.b)
        }
    }

    private func applyHex() {
        guard let parsed = ColourMaths.rgb(hex: hexText) else {
            hexText = ColourMaths.hex(rgb)
            return
        }
        red = Double(parsed.r)
        green = Double(parsed.g)
        blue = Double(parsed.b)
        hexText = ColourMaths.hex(parsed)
    }

    /// The system colour picker sets RGB (and switches to RGB entry).
    private var pickerBinding: Binding<Color> {
        Binding {
            swatch
        } set: { colour in
            let resolved = colour.resolve(in: EnvironmentValues())
            func byte(_ v: Float) -> Double { (min(1, max(0, Double(v))) * 255).rounded() }
            input = .rgb
            red = byte(resolved.red)
            green = byte(resolved.green)
            blue = byte(resolved.blue)
        }
    }
}

/// One channel: name and value, a slider with a coloured track, and a field
/// to type the exact number.
private struct ChannelRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let track: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: clampedValue, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                if !unit.isEmpty {
                    Text(unit).foregroundStyle(.secondary).frame(width: 18, alignment: .leading)
                }
            }
            Slider(value: $value, in: range, step: 1)
                .tint(.clear)
                .background {
                    Capsule()
                        .fill(LinearGradient(colors: track, startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
                }
                .accessibilityLabel(title)
        }
        .padding(.vertical, 2)
    }

    /// Typed numbers are kept in range.
    private var clampedValue: Binding<Double> {
        Binding {
            value
        } set: { newValue in
            value = min(range.upperBound, max(range.lowerBound, newValue.rounded()))
        }
    }
}
