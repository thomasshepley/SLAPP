// Companion/Views/FlickerToolView.swift
import Charts
import SwiftUI

/// Will this light flicker on camera, and how to stop it: pick the fixture
/// (its refresh rate comes from the library), set the camera, read the
/// verdict and the fixes.
struct FlickerToolView: View {
    let library: FixtureLibrary
    @AppStorage(CompanionSettings.mainsHzKey) private var mainsHz: Int = 50
    @State private var fixtureID: String?
    @State private var source: FlickerSource = .unknown
    @State private var refreshHz: Double = 1000
    @State private var dimmer: Double = 50
    @State private var fps: Double = 25
    @State private var shutterAngle: Double = 180

    private let flickerLibrary = CompanionLibrary.flicker

    private var fixture: Fixture? { fixtureID.flatMap(library.fixture(id:)) }
    private var profile: FlickerProfile? { fixture.map(flickerLibrary.profile(for:)) }
    private var camera: Flicker.Camera { Flicker.Camera(fps: fps, shutterAngle: shutterAngle) }
    private var pulseHz: Double { Flicker.pulseHz(source, refreshHz: refreshHz, mainsHz: Double(mainsHz)) }
    private var depth: Double {
        Flicker.depth(source, dimmerPercent: dimmer, pwmBelowPercent: profile?.pwmBelowPercent, powerW: fixture?.powerW)
    }
    private var analysis: Flicker.Analysis { Flicker.analyse(pulseHz: pulseHz, depth: depth, camera: camera) }
    private var usesDimmer: Bool { source == .pwm || source == .unknown }

    var body: some View {
        Form {
            lightSection
            cameraSection
            Section {
                verdictCard
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            fixesSection
        }
        .navigationTitle(CompanionSection.flicker.title)
        .onChange(of: fixtureID) { _, _ in applyProfile() }
    }

    // MARK: - The light

    private var lightSection: some View {
        Section {
            FixturePickerRow(library: library, fixtureID: $fixtureID, noneTitle: "Enter it myself")
            Picker("Type of light", selection: $source) {
                ForEach(FlickerSource.allCases) { Text($0.title).tag($0) }
            }
            if source.followsMains {
                LabeledContent("Pulses at", value: "\(Int(pulseHz)) Hz (twice the \(mainsHz) Hz mains)")
            } else if source != .constantCurrent {
                if let options = profile?.selectableHz, options.count > 1 {
                    Picker("Fixture's refresh setting", selection: $refreshHz) {
                        ForEach(options, id: \.self) { Text(Self.hz($0)).tag($0) }
                    }
                }
                NumberField(title: "Refresh rate", value: $refreshHz, unit: "Hz", places: 0)
            }
            if usesDimmer {
                VStack(alignment: .leading) {
                    LabeledContent("Dimmer", value: "\(Int(dimmer))%")
                    Slider(value: $dimmer, in: 1 ... 100, step: 1)
                }
            }
            if let note = profileNote {
                Label(note, systemImage: profile?.isResearched == true ? "checkmark.seal" : "questionmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("The light")
        } footer: {
            Text("LEDs flicker most when dimmed: they pulse on and off (PWM) to look dimmer. Mains frequency is in Units & Mains.")
        }
    }

    private var profileNote: String? {
        guard let fixture, let profile else { return nil }
        var parts: [String] = []
        if let notes = profile.notes { parts.append(notes) }
        if profile.isResearched {
            parts.append(profile.confidence == "family" ? "Figures from a sibling model's manual." : "Figures from \(fixture.manufacturer)'s published specs.")
        } else if !profile.kind.followsMains {
            parts.append("No published refresh rate for this one. Check its menu or manual and type it in.")
        }
        if let fps = profile.flickerFreeUpToFps { parts.append("\(fixture.manufacturer) says flicker-free up to \(Int(fps)) fps.") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - The camera

    private var cameraSection: some View {
        Section {
            Picker("Frame rate", selection: $fps) {
                ForEach(Flicker.commonFrameRates, id: \.self) { Text("\(Self.fpsText($0)) fps").tag($0) }
            }
            VStack(alignment: .leading) {
                LabeledContent("Shutter") {
                    Text("\(shutterAngle.formatted(.number.precision(.fractionLength(0 ... 1))))°  ·  1/\(Int((1 / camera.exposure).rounded())) s")
                        .monospacedDigit()
                }
                Slider(value: $shutterAngle, in: 11.25 ... 360, step: 0.1)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Flicker.commonShutterAngles, id: \.self) { angle in
                            Button("\(angle.formatted())°") { withAnimation { shutterAngle = angle } }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(abs(angle - shutterAngle) < 0.05 ? Color.accentColor : Color.secondary)
                                .controlSize(.small)
                        }
                    }
                }
            }
        } header: {
            Text("The camera")
        }
    }

    // MARK: - Verdict

    private var verdictCard: some View {
        let result = analysis
        let (title, symbol, colour): (String, String, Color) = {
            switch result.verdict {
            case .safe: return ("No flicker", "checkmark.circle.fill", Color.green)
            case .watch: return ("Watch it", "exclamationmark.triangle.fill", Color.orange)
            case .flickers: return ("Will flicker", "xmark.octagon.fill", Color.red)
            }
        }()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 34))
                    .foregroundStyle(colour)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title2.weight(.bold))
                    Text(verdictDetail(result)).font(.callout).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                StatTile(title: "Brightness swing", value: "±\((result.wobble * 100).formatted(.number.precision(.fractionLength(1))))%",
                         symbol: "waveform.path", tint: colour)
                StatTile(title: "In the footage", value: result.beatHz == 0 ? "Steady" : "\(Self.rate(result.beatHz))",
                         symbol: "film", tint: .secondary)
            }
            frameChart(colour: colour)
        }
        .animation(.snappy, value: result)
    }

    private func verdictDetail(_ result: Flicker.Analysis) -> String {
        switch result.verdict {
        case .safe:
            return result.wobble < 0.01 ? "Each frame gets the same light." : "Locked to the frame rate, so it doesn't move."
        case .watch:
            return result.beatHz == 0
                ? "Steady frame to frame, but rolling-shutter cameras may show still bands."
                : "A faint pulse. It may show in a grade or on a big screen - test it."
        case .flickers:
            return "The light's \(Self.hz(pulseHz)) pulse beats against \(Self.fpsText(fps)) fps."
        }
    }

    /// Two seconds of footage, frame by frame (1 = average brightness).
    private func frameChart(colour: Color) -> some View {
        let frames = Int(min(120, max(24, fps * 2)))
        let values = Flicker.frameBrightness(pulseHz: pulseHz, depth: depth, camera: camera, frames: frames)
        let spread = max(0.05, (values.map { abs($0 - 1) }.max() ?? 0) * 1.2)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Each frame's brightness over 2 seconds")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                RuleMark(y: .value("Average", 1.0))
                    .foregroundStyle(.secondary.opacity(0.4))
                ForEach(Array(values.enumerated()), id: \.offset) { frame, value in
                    LineMark(x: .value("Frame", frame), y: .value("Brightness", value))
                        .foregroundStyle(colour)
                    PointMark(x: .value("Frame", frame), y: .value("Brightness", value))
                        .foregroundStyle(colour)
                        .symbolSize(12)
                }
            }
            .chartYScale(domain: (1 - spread) ... (1 + spread))
            .chartYAxis {
                AxisMarks(values: [1 - spread, 1.0, 1 + spread]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v == 1 ? "avg" : "\(v > 1 ? "+" : "")\(Int(((v - 1) * 100).rounded()))%")
                        }
                    }
                }
            }
            .chartXAxisLabel("frame")
            .frame(height: 130)
        }
    }

    // MARK: - Fixes

    private struct Fix: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    private var fixes: [Fix] {
        var fixes: [Fix] = []
        let result = analysis
        if result.verdict == .safe {
            fixes.append(Fix(symbol: "checkmark.circle", title: "Good to go",
                             detail: "Still shoot a quick test at the real frame rate, especially before high speed."))
        }

        let angles = Flicker.safeShutterAngles(pulseHz: pulseHz, fps: fps, near: shutterAngle)
            .filter { abs($0 - shutterAngle) > 0.05 }
        if result.verdict != .safe, !angles.isEmpty {
            let list = angles.map { "\($0.formatted())°" }.joined(separator: ", ")
            fixes.append(Fix(symbol: "camera.aperture", title: "Change the shutter to \(angles[0].formatted())°",
                             detail: "Shutter angles that catch whole pulses at \(Self.fpsText(fps)) fps: \(list)."))
        }

        if result.verdict != .safe {
            let rates = Flicker.safeFrameRates(pulseHz: pulseHz, depth: depth, shutterAngle: shutterAngle)
                .filter { $0 != fps }
                .sorted { abs($0 - fps) < abs($1 - fps) }
                .prefix(3)
            if !rates.isEmpty {
                fixes.append(Fix(symbol: "film.stack", title: "Or shoot at \(Self.fpsText(rates.first!)) fps",
                                 detail: "Safe at \(shutterAngle.formatted())°: \(rates.map { Self.fpsText($0) }.joined(separator: ", ")) fps."))
            }
        }

        switch source {
        case .pwm, .unknown:
            if result.verdict != .safe {
                if let options = profile?.selectableHz, let fastest = options.max(), fastest > refreshHz {
                    fixes.append(Fix(symbol: "slider.horizontal.3", title: "Set the fixture to \(Self.hz(fastest))",
                                     detail: "In its menu (refresh / PWM frequency). Faster refresh means far less flicker."))
                } else if profile?.highSpeedMode == true {
                    fixes.append(Fix(symbol: "hare", title: "Turn on its high-speed mode",
                                     detail: "Usually in the fixture's menu. It raises the refresh rate for high frame rates."))
                } else {
                    fixes.append(Fix(symbol: "slider.horizontal.3", title: "Raise the fixture's refresh rate",
                                     detail: "Look for PWM frequency, refresh rate, flicker-free or high-speed mode in its menu."))
                }
                if let level = Flicker.safeDimmerLevel(pulseHz: pulseHz, camera: camera, pwmBelowPercent: profile?.pwmBelowPercent),
                   level > dimmer {
                    fixes.append(Fix(symbol: "sun.max", title: "Run it at \(Int(level))% or more",
                                     detail: "PWM flicker is worst when dimmed. Bring the level up and take it down with ND, scrim, a net or distance."))
                } else {
                    fixes.append(Fix(symbol: "sun.max", title: "Dim less, cut it another way",
                                     detail: "PWM flicker is worst at low levels. Run it near full and use ND, scrim, a net or distance."))
                }
                if let threshold = profile?.pwmBelowPercent {
                    fixes.append(Fix(symbol: "arrow.up.to.line", title: "Keep it above \(Int(threshold))%",
                                     detail: "Above that it's constant current: no PWM at all."))
                }
            }
        case .hmiMagnetic:
            fixes.append(Fix(symbol: "bolt.badge.checkmark", title: "Swap to a flicker-free ballast",
                             detail: "A magnetic ballast pulses the arc hard at \(Int(pulseHz)) Hz. Electronic ballasts are safe at normal speeds."))
        case .hmiElectronic:
            if fps > 100 {
                fixes.append(Fix(symbol: "hare", title: "Switch the ballast to high-speed mode",
                                 detail: "Flicker-free ballasts are safe at normal frame rates; for high speed use their high-frequency (often 1 kHz) mode."))
            }
        case .tungsten:
            if result.verdict != .safe {
                fixes.append(Fix(symbol: "lightbulb", title: "Bigger lamp, or a DC / flicker-free supply",
                                 detail: "Heavy filaments barely ripple. Small lamps at high speed show the mains pulse."))
            }
        case .fluorescent:
            fixes.append(Fix(symbol: "bolt.badge.checkmark", title: "Use high-frequency ballasts",
                             detail: "Magnetic-ballast tubes pulse at \(Int(pulseHz)) Hz. Kino-style HF ballasts are safe."))
        case .constantCurrent:
            break
        }
        return fixes
    }

    private var fixesSection: some View {
        Section {
            ForEach(fixes) { fix in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fix.title).font(.body.weight(.semibold))
                        Text(fix.detail).font(.callout).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: fix.symbol).foregroundStyle(.tint)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(analysis.verdict == .safe ? "Notes" : "How to get rid of it")
        } footer: {
            Text("A guide from the maths of exposure and pulse rate. Real lights and sensors vary, so test at the frame rate before you roll.")
        }
    }

    // MARK: - Helpers

    private func applyProfile() {
        guard let profile else { return }
        source = profile.kind
        if let hz = profile.defaultHz ?? profile.selectableHz?.first { refreshHz = hz }
    }

    static func hz(_ value: Double) -> String {
        value >= 1000 ? "\((value / 1000).formatted(.number.precision(.fractionLength(0 ... 1)))) kHz" : "\(Int(value)) Hz"
    }

    static func fpsText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 3)))
    }

    /// "4 times a second" or "once every 2.5 s".
    static func rate(_ hz: Double) -> String {
        hz >= 1 ? "Pulses \(hz.formatted(.number.precision(.fractionLength(0 ... 1)))) / s"
            : "Once every \((1 / hz).formatted(.number.precision(.fractionLength(0 ... 1)))) s"
    }
}
