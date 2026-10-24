// Companion/Calc/Flicker.swift
import Foundation

/// How a light's output pulses, which is what a camera can catch as flicker.
enum FlickerSource: String, CaseIterable, Codable, Identifiable {
    /// LED dimmed by switching on and off (PWM) at its refresh rate.
    case pwm
    /// LED with a constant-current driver: steady at every level.
    case constantCurrent
    /// Tungsten on mains: a small ripple at twice the mains frequency.
    case tungsten
    /// HMI on a magnetic ballast: a deep pulse at twice the mains frequency.
    case hmiMagnetic
    /// HMI on an electronic flicker-free (square wave) ballast.
    case hmiElectronic
    /// Fluorescent on a magnetic ballast.
    case fluorescent
    case unknown

    var id: Self { self }

    var title: String {
        switch self {
        case .pwm: "LED (PWM dimming)"
        case .constantCurrent: "LED (constant current)"
        case .tungsten: "Tungsten"
        case .hmiMagnetic: "HMI, magnetic ballast"
        case .hmiElectronic: "HMI, flicker-free ballast"
        case .fluorescent: "Fluorescent, magnetic ballast"
        case .unknown: "LED (not sure)"
        }
    }

    /// Whether the pulse rate comes from the mains rather than the fixture.
    var followsMains: Bool { [.tungsten, .hmiMagnetic, .fluorescent, .hmiElectronic].contains(self) }
}

/// What the library knows about a fixture's flicker (Resources/Companion/flicker.json).
struct FlickerProfile: Codable, Equatable {
    var kind: FlickerSource
    var defaultHz: Double?
    var selectableHz: [Double]?
    var highSpeedMode: Bool?
    /// Constant current above this level, PWM below it.
    var pwmBelowPercent: Double?
    var flickerFreeUpToFps: Double?
    var notes: String?
    var source: String?
    /// "published", "family" or "none".
    var confidence: String?

    private enum CodingKeys: String, CodingKey {
        case kind, defaultHz, selectableHz, highSpeedMode, pwmBelowPercent, flickerFreeUpToFps, notes, source, confidence
    }

    init(kind: FlickerSource, defaultHz: Double? = nil, selectableHz: [Double]? = nil, highSpeedMode: Bool? = nil,
         pwmBelowPercent: Double? = nil, flickerFreeUpToFps: Double? = nil, notes: String? = nil,
         source: String? = nil, confidence: String? = nil) {
        self.kind = kind
        self.defaultHz = defaultHz
        self.selectableHz = selectableHz
        self.highSpeedMode = highSpeedMode
        self.pwmBelowPercent = pwmBelowPercent
        self.flickerFreeUpToFps = flickerFreeUpToFps
        self.notes = notes
        self.source = source
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decode(FlickerSource.self, forKey: .kind)) ?? .unknown
        defaultHz = try c.decodeIfPresent(Double.self, forKey: .defaultHz)
        selectableHz = try c.decodeIfPresent([Double].self, forKey: .selectableHz)
        highSpeedMode = try c.decodeIfPresent(Bool.self, forKey: .highSpeedMode)
        pwmBelowPercent = try c.decodeIfPresent(Double.self, forKey: .pwmBelowPercent)
        flickerFreeUpToFps = try c.decodeIfPresent(Double.self, forKey: .flickerFreeUpToFps)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence)
    }

    /// Researched: a figure from the manufacturer, or a sibling model's.
    var isResearched: Bool { confidence == "published" || confidence == "family" }
}

enum Flicker {
    struct Camera: Equatable {
        var fps: Double
        /// Shutter angle in degrees (180 = half the frame time).
        var shutterAngle: Double

        /// Exposure time in seconds.
        var exposure: Double { shutterAngle / 360 / fps }
    }

    enum Verdict: Equatable {
        case safe
        /// Subtle, or bands that don't move (rolling-shutter cameras).
        case watch
        case flickers
    }

    struct Analysis: Equatable {
        /// Frame-to-frame brightness swing, as a fraction (0.05 = ±5%).
        let wobble: Double
        /// How often the flicker pulses in the footage, Hz. 0 = locked (doesn't move).
        let beatHz: Double
        let verdict: Verdict
        /// Light pulses captured per exposure.
        let cyclesPerExposure: Double
    }

    /// A guess at the source from the library's category, until a fixture has
    /// researched data.
    static func typicalProfile(category: String?, model: String = "") -> FlickerProfile {
        let text = "\(category ?? "") \(model)".lowercased()
        if text.contains("tungsten") { return FlickerProfile(kind: .tungsten, confidence: "none") }
        if text.contains("hmi") {
            return FlickerProfile(kind: .hmiElectronic,
                                  notes: "Most HMIs on set run on flicker-free electronic ballasts; an old magnetic ballast flickers badly.",
                                  confidence: "none")
        }
        if text.contains("fluorescent") { return FlickerProfile(kind: .fluorescent, confidence: "none") }
        return FlickerProfile(kind: .unknown, defaultHz: nil, confidence: "none")
    }

    /// The pulse frequency in Hz for a source. Mains-driven sources pulse at
    /// twice the mains frequency; an unknown LED is assumed to refresh at 1 kHz.
    static func pulseHz(_ source: FlickerSource, refreshHz: Double?, mainsHz: Double) -> Double {
        switch source {
        case .tungsten, .hmiMagnetic, .fluorescent, .hmiElectronic: 2 * mainsHz
        case .pwm, .constantCurrent: refreshHz ?? 1000
        case .unknown: refreshHz ?? 1000
        }
    }

    /// How deep the pulse is, relative to the average output (the first
    /// harmonic). PWM at duty D: 2·sin(πD)/(πD), so it vanishes at 100%.
    static func depth(_ source: FlickerSource, dimmerPercent: Double, pwmBelowPercent: Double? = nil,
                      powerW: Double? = nil) -> Double {
        let duty = min(1, max(0.005, dimmerPercent / 100))
        switch source {
        case .pwm, .unknown:
            if let threshold = pwmBelowPercent, dimmerPercent >= threshold { return 0.01 }
            return duty >= 0.999 ? 0 : min(2, 2 * sin(.pi * duty) / (.pi * duty))
        case .constantCurrent: return 0.01
        case .tungsten: return (powerW ?? 1000) <= 300 ? 0.15 : 0.07   // small filaments cool faster
        case .hmiMagnetic: return 0.8
        case .hmiElectronic: return 0.04
        case .fluorescent: return 0.35
        }
    }

    /// sin(πx)/(πx): how much of a sinusoidal pulse survives averaging over
    /// an exposure that's x cycles long.
    static func sinc(_ x: Double) -> Double {
        abs(x) < 1e-9 ? 1 : sin(.pi * x) / (.pi * x)
    }

    static func analyse(pulseHz: Double, depth: Double, camera: Camera) -> Analysis {
        let cycles = pulseHz * camera.exposure
        let wobble = abs(depth * sinc(cycles))
        // The pulse rate's distance from a whole multiple of the frame rate is
        // how fast the flicker rolls through the footage.
        let ratio = pulseHz / camera.fps
        let beat = abs(pulseHz - camera.fps * ratio.rounded())
        let locked = beat < 0.01
        let verdict: Verdict
        if wobble < 0.01 {
            verdict = .safe
        } else if locked {
            verdict = wobble > 0.03 ? .watch : .safe   // same every frame; may band on a rolling shutter
        } else {
            verdict = wobble > 0.03 ? .flickers : .watch
        }
        return Analysis(wobble: wobble, beatHz: locked ? 0 : beat, verdict: verdict, cyclesPerExposure: cycles)
    }

    /// Relative brightness of each frame (1 = average), for the chart.
    static func frameBrightness(pulseHz: Double, depth: Double, camera: Camera, frames: Int) -> [Double] {
        let exposure = camera.exposure
        let factor = depth * sinc(pulseHz * exposure)
        return (0 ..< frames).map { frame in
            let start = Double(frame) / camera.fps
            return 1 + factor * cos(2 * .pi * pulseHz * (start + exposure / 2))
        }
    }

    /// Shutter angles that capture whole pulses (flicker-free for that light),
    /// nearest the current angle first. 360·fps·k / f for whole k.
    static func safeShutterAngles(pulseHz: Double, fps: Double, near angle: Double, count: Int = 3) -> [Double] {
        guard pulseHz > 0, fps > 0 else { return [] }
        let step = 360 * fps / pulseHz
        guard step <= 360 else { return [] }
        let angles = stride(from: step, through: 360.0001, by: step).map { (($0 * 10).rounded() / 10) }
        return Array(angles.sorted { abs($0 - angle) < abs($1 - angle) }.prefix(count))
    }

    static let commonFrameRates: [Double] = [23.976, 24, 25, 29.97, 30, 48, 50, 59.94, 60, 100, 120, 150, 200, 240]
    static let commonShutterAngles: [Double] = [45, 90, 144, 172.8, 180, 270, 360]

    /// Frame rates from the common list that are safe at this shutter angle.
    static func safeFrameRates(pulseHz: Double, depth: Double, shutterAngle: Double) -> [Double] {
        commonFrameRates.filter {
            analyse(pulseHz: pulseHz, depth: depth, camera: Camera(fps: $0, shutterAngle: shutterAngle)).verdict == .safe
        }
    }

    /// The lowest dimmer level (in 5% steps) that's safe, for PWM lights.
    static func safeDimmerLevel(pulseHz: Double, camera: Camera, pwmBelowPercent: Double?) -> Double? {
        for level in stride(from: 5.0, through: 100, by: 5) {
            let d = depth(.pwm, dimmerPercent: level, pwmBelowPercent: pwmBelowPercent)
            if analyse(pulseHz: pulseHz, depth: d, camera: camera).verdict == .safe { return level }
        }
        return nil
    }
}

/// Researched flicker data by fixture id (Resources/Companion/flicker.json).
/// Missing or unreadable is fine: the tool falls back to the fixture's type.
struct FlickerLibrary {
    let profiles: [String: FlickerProfile]

    static func bundled(in bundle: Bundle = .main) -> FlickerLibrary {
        guard let url = bundle.url(forResource: "flicker", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let profiles = try? JSONDecoder().decode([String: FlickerProfile].self, from: data) else {
            return FlickerLibrary(profiles: [:])
        }
        return FlickerLibrary(profiles: profiles)
    }

    /// Researched data if there is any, otherwise a typical profile for its type.
    func profile(for fixture: Fixture) -> FlickerProfile {
        let typical = Flicker.typicalProfile(category: fixture.category, model: fixture.model)
        guard let known = profiles[fixture.id] else { return typical }
        if known.kind != .unknown || known.defaultHz != nil { return known }
        // Nothing on how it pulses, but keep what was found (claims, notes).
        var merged = known
        merged.kind = typical.kind
        if merged.notes == nil { merged.notes = typical.notes }
        return merged
    }
}
