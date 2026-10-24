import XCTest
@testable import TitanDeck

/// Flicker, the letter index, colour conversion extras and the sun's map line.
final class CompanionToolsTests: XCTestCase {
    // MARK: Flicker

    private func analyse(_ source: FlickerSource, refresh: Double? = nil, dimmer: Double = 100,
                         fps: Double, angle: Double, mains: Double = 50) -> Flicker.Analysis {
        let hz = Flicker.pulseHz(source, refreshHz: refresh, mainsHz: mains)
        return Flicker.analyse(pulseHz: hz, depth: Flicker.depth(source, dimmerPercent: dimmer),
                               camera: Flicker.Camera(fps: fps, shutterAngle: angle))
    }

    func testMagneticHMIAt24fps180FlickersInEurope() {
        let result = analyse(.hmiMagnetic, fps: 24, angle: 180)
        XCTAssertEqual(result.verdict, .flickers)
        XCTAssertEqual(result.beatHz, 4, accuracy: 0.001, "100 Hz against 24 fps beats at 4 Hz")
    }

    func testTheClassic172Point8IsSafe() {
        XCTAssertEqual(analyse(.hmiMagnetic, fps: 24, angle: 172.8).verdict, .safe)
        XCTAssertEqual(analyse(.hmiMagnetic, fps: 25, angle: 180).verdict, .safe)
        XCTAssertEqual(analyse(.hmiMagnetic, fps: 30, angle: 180, mains: 60).verdict, .safe)
    }

    func testSafeShutterAnglesFor24fpsUnder100Hz() {
        XCTAssertEqual(Flicker.safeShutterAngles(pulseHz: 100, fps: 24, near: 180), [172.8, 259.2, 86.4])
        XCTAssertTrue(Flicker.safeShutterAngles(pulseHz: 10, fps: 24, near: 180).isEmpty, "pulse slower than the frame rate")
    }

    func testPWMDepthVanishesAtFullAndGrowsWhenDimmed() {
        XCTAssertEqual(Flicker.depth(.pwm, dimmerPercent: 100), 0)
        XCTAssertGreaterThan(Flicker.depth(.pwm, dimmerPercent: 10), Flicker.depth(.pwm, dimmerPercent: 50))
        XCTAssertLessThanOrEqual(Flicker.depth(.pwm, dimmerPercent: 1), 2)
        XCTAssertEqual(Flicker.depth(.pwm, dimmerPercent: 60, pwmBelowPercent: 40), 0.01, "constant current above the threshold")
    }

    func testFastPWMIsFineAtNormalSpeedButNotHighSpeed() {
        XCTAssertEqual(analyse(.pwm, refresh: 25_000, dimmer: 20, fps: 240, angle: 180).verdict, .safe)
        XCTAssertNotEqual(analyse(.pwm, refresh: 600, dimmer: 20, fps: 240, angle: 180).verdict, .safe)
    }

    func testSafeDimmerLevelForPWM() {
        let camera = Flicker.Camera(fps: 240, shutterAngle: 180)
        let level = Flicker.safeDimmerLevel(pulseHz: 1000, camera: camera, pwmBelowPercent: nil)
        XCTAssertNotNil(level)
        if let level {
            XCTAssertEqual(Flicker.analyse(pulseHz: 1000, depth: Flicker.depth(.pwm, dimmerPercent: level), camera: camera).verdict, .safe)
        }
    }

    func testFrameBrightnessIsFlatWhenSafe() {
        let flat = Flicker.frameBrightness(pulseHz: 100, depth: 0.8, camera: Flicker.Camera(fps: 25, shutterAngle: 180), frames: 50)
        XCTAssertLessThan(flat.map { abs($0 - 1) }.max() ?? 1, 1e-9)
        let wobbly = Flicker.frameBrightness(pulseHz: 100, depth: 0.8, camera: Flicker.Camera(fps: 24, shutterAngle: 180), frames: 48)
        XCTAssertGreaterThan(wobbly.map { abs($0 - 1) }.max() ?? 0, 0.02)
    }

    func testTypicalProfilesFromCategory() {
        XCTAssertEqual(Flicker.typicalProfile(category: "Tungsten Fresnel").kind, .tungsten)
        XCTAssertEqual(Flicker.typicalProfile(category: "HMI Fresnel").kind, .hmiElectronic)
        XCTAssertEqual(Flicker.typicalProfile(category: "LED Panel").kind, .unknown)
    }

    func testFlickerProfileDecodesResearchShape() throws {
        let json = #"{"kind":"pwm","defaultHz":1200,"selectableHz":[600,1200,25000],"highSpeedMode":true,"pwmBelowPercent":null,"flickerFreeUpToFps":null,"notes":"x","source":"https://example.com","confidence":"published"}"#
        let profile = try JSONDecoder().decode(FlickerProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.kind, .pwm)
        XCTAssertEqual(profile.selectableHz, [600, 1200, 25000])
        XCTAssertTrue(profile.isResearched)
        let odd = try JSONDecoder().decode(FlickerProfile.self, from: Data(#"{"kind":"plasma"}"#.utf8))
        XCTAssertEqual(odd.kind, .unknown)
    }

    // MARK: Letter index

    func testLettersFoldAccentsAndDigits() {
        XCTAssertEqual(LetterIndex.letter(for: "Élation"), "E")
        XCTAssertEqual(LetterIndex.letter(for: "aputure"), "A")
        XCTAssertEqual(LetterIndex.letter(for: "3Dlight"), "#")
        XCTAssertEqual(LetterIndex.alphabet.count, 27)
    }

    func testSectionsAreAlphabeticalWithHashLast() {
        let sections = LetterIndex.sections(["Nanlite", "ARRI", "Astera", "8K Lights", "Godox"])
        XCTAssertEqual(sections.map(\.letter), ["A", "G", "N", "#"])
        XCTAssertEqual(sections.first?.names, ["ARRI", "Astera"])
    }

    func testDraggingSnapsToNearestLetterWithEntries() {
        let available = ["A", "G", "N"]
        XCTAssertEqual(LetterIndex.letter(atFraction: 0, available: available), "A")
        XCTAssertEqual(LetterIndex.letter(atFraction: 1, available: available), "N")
        XCTAssertEqual(LetterIndex.letter(atFraction: 6.2 / 27, available: available), "G")
        XCTAssertNil(LetterIndex.letter(atFraction: 0.5, available: []))
    }

    // MARK: Colour

    func testHexBothWays() {
        XCTAssertEqual(ColourMaths.hex(RGB(r: 38, g: 179, b: 158)), "#26B39E")
        XCTAssertEqual(ColourMaths.rgb(hex: "#26b39e"), RGB(r: 38, g: 179, b: 158))
        XCTAssertEqual(ColourMaths.rgb(hex: "F80"), RGB(r: 255, g: 136, b: 0))
        XCTAssertNil(ColourMaths.rgb(hex: "nope"))
    }

    func testHSIClipping() {
        XCTAssertFalse(ColourMaths.isClipped(HSI(h: 0, s: 1, i: 0.33)), "pure red at a third is makeable")
        XCTAssertTrue(ColourMaths.isClipped(HSI(h: 0, s: 1, i: 0.9)), "fully saturated can't be that bright")
        XCTAssertFalse(ColourMaths.isClipped(HSI(h: 200, s: 0, i: 0.9)), "white at 90% is fine")
    }

    func testTintCorrectionInPlainTerms() {
        let green = ColourMaths.tintCorrection(duv: 0.0015)
        XCTAssertEqual(green.looks, .green)
        XCTAssertEqual(green.gelName, "Minus Green")
        XCTAssertEqual(green.strength, "1/4")
        XCTAssertEqual(green.leeNumber, "249")
        let magenta = ColourMaths.tintCorrection(duv: -0.006)
        XCTAssertEqual(magenta.gelName, "Plus Green")
        XCTAssertEqual(magenta.strength, "Full")
        XCTAssertEqual(magenta.leeNumber, "244")
        XCTAssertEqual(ColourMaths.tintCorrection(duv: 0.0002).looks, .neutral)
        XCTAssertTrue(ColourMaths.tintCorrection(duv: 0.01).beyondFull)
    }

    // MARK: Sun on the map

    func testDestinationPointsAlongTheBearing() {
        let north = Sun.destination(latitude: 51.5, longitude: -0.13, bearing: 0, metres: 1000)
        XCTAssertEqual(north.latitude - 51.5, 1000 / 111_195, accuracy: 1e-5)
        XCTAssertEqual(north.longitude, -0.13, accuracy: 1e-9)
        let east = Sun.destination(latitude: 0, longitude: 179.999, bearing: 90, metres: 1000)
        XCTAssertLessThan(east.longitude, -179, "wraps across the date line")
    }
}
