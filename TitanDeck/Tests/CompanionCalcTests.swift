// Tests/CompanionCalcTests.swift
// Ported from the lighting companion's calc.test.ts / calc2.test.ts, so the
// Swift maths gives the same answers as the old app.
import XCTest
@testable import TitanDeck

final class CompanionCalcTests: XCTestCase {
    // MARK: Dimming

    func testSquareLawRoundTrips() {
        let curve = DimmingCurve(type: .square)
        XCTAssertEqual(Dimming.output(atDmx: 0.5, curve: curve), 0.25, accuracy: 1e-9)
        XCTAssertEqual(Dimming.dmx(forOutput: 0.25, curve: curve), 0.5, accuracy: 1e-9)
    }

    func testMeasuredCurveInterpolates() {
        let curve = DimmingCurve(type: .measured, samples: [
            DimmingSample(dmxFraction: 0, outputFraction: 0),
            DimmingSample(dmxFraction: 0.5, outputFraction: 0.1),
            DimmingSample(dmxFraction: 1, outputFraction: 1),
        ])
        XCTAssertEqual(Dimming.output(atDmx: 0.25, curve: curve), 0.05, accuracy: 1e-9)
        XCTAssertEqual(Dimming.output(atDmx: 0.75, curve: curve), 0.55, accuracy: 1e-9)
        XCTAssertEqual(Dimming.dmx(forOutput: 0.55, curve: curve), 0.75, accuracy: 1e-9)
    }

    func testEveryCurveInvertsItself() {
        for kind in [DimmingCurve.Kind.linear, .square, .scurve, .log] {
            let curve = DimmingCurve(type: kind)
            for x in stride(from: 0.05, through: 1, by: 0.05) {
                let y = Dimming.output(atDmx: x, curve: curve)
                XCTAssertEqual(Dimming.dmx(forOutput: y, curve: curve), x, accuracy: 1e-6, "\(kind) at \(x)")
            }
        }
    }

    // MARK: Stops

    func testOneStopDoublesOnALinearFixture() {
        let result = Stops.compute(dmx: 128, curve: .linear, luxAt1m: 1000, offsets: [1, -1])
        XCTAssertEqual(result.rows.first { $0.stops == -1 }?.dmx, 64)
        XCTAssertEqual(result.rows.first { $0.stops == 1 }?.dmx, 255)
        XCTAssertEqual(result.rows.first { $0.stops == 1 }?.clipped, true)
    }

    func testStopsReportCurrentLux() {
        let full = Stops.compute(dmx: 255, curve: .linear, luxAt1m: 1000, offsets: [])
        XCTAssertEqual(full.currentLux ?? 0, 1000, accuracy: 1e-9)
        XCTAssertEqual(full.currentPercent, 100)
        XCTAssertNil(Stops.compute(dmx: 100, curve: .linear, luxAt1m: nil).currentLux)
    }

    func testStopsOnASquareLawFixture() {
        // Half DMX on square law is a quarter of the light; one stop up is half
        // the light, which needs DMX 0.707 x 255 = 180.
        let result = Stops.compute(dmx: 128, curve: DimmingCurve(type: .square), luxAt1m: nil, offsets: [1])
        XCTAssertEqual(result.rows[0].dmx, 181)   // 128/255 rounds a touch above half
        XCTAssertFalse(result.rows[0].clipped)
    }

    // MARK: Photometry

    func testInverseSquareLaw() {
        XCTAssertEqual(Photometry.lux(atDistance: 2, luxAt1m: 1000), 250, accuracy: 1e-9)
        XCTAssertEqual(Photometry.distance(forLux: 250, luxAt1m: 1000), 2, accuracy: 1e-9)
        XCTAssertEqual(Photometry.lux(atDistance: 0, luxAt1m: 1000), .infinity)
    }

    func testBeamGeometry() {
        XCTAssertEqual(Photometry.beamDiameter(angle: 90, distance: 5), 10, accuracy: 1e-9)
        XCTAssertEqual(Photometry.throwDistance(angle: 90, diameter: 10), 5, accuracy: 1e-9)
        XCTAssertEqual(Photometry.throwDistance(angle: 0, diameter: 10), .infinity)
    }

    // MARK: Colour

    func testKelvinMiredAndShifts() {
        XCTAssertEqual(ColourMaths.mired(kelvin: 10_000), 100, accuracy: 1e-9)
        let shift = ColourMaths.correctionShift(from: 5600, to: 3200)
        XCTAssertEqual(ColourMaths.apply(shift: shift, to: 5600), 3200, accuracy: 0.5)
    }

    func testRgbHsiRoundTrip() {
        let hsi = ColourMaths.hsi(from: RGB(r: 255, g: 0, b: 0))
        XCTAssertGreaterThan(ColourMaths.rgb(from: hsi).r, 240)
        let teal = RGB(r: 40, g: 180, b: 160)
        let back = ColourMaths.rgb(from: ColourMaths.hsi(from: teal))
        XCTAssertLessThanOrEqual(abs(back.r - teal.r), 2)
        XCTAssertLessThanOrEqual(abs(back.g - teal.g), 2)
        XCTAssertLessThanOrEqual(abs(back.b - teal.b), 2)
    }

    func testTunableWhite() {
        let cct = ColourMaths.cct(percent: 50, minK: 2700, maxK: 6500)
        XCTAssertGreaterThan(cct, 2700)
        XCTAssertLessThan(cct, 6500)
        XCTAssertEqual(ColourMaths.percent(cct: cct, minK: 2700, maxK: 6500), 50, accuracy: 0.5)
        XCTAssertEqual(ColourMaths.cct(percent: 0, minK: 3200, maxK: 5600), 3200)
        XCTAssertEqual(ColourMaths.cct(percent: 100, minK: 3200, maxK: 5600), 5600)
    }

    func testTint() {
        XCTAssertEqual(ColourMaths.tint(duv: 0.003).direction, .green)
        XCTAssertEqual(ColourMaths.tint(duv: -0.003).direction, .magenta)
        XCTAssertEqual(ColourMaths.tint(duv: 0).direction, .neutral)
        XCTAssertEqual(ColourMaths.tint(duv: 0.0028).ccEighths, 4)
    }

    func testGelSuggestions() {
        XCTAssertEqual(ColourMaths.suggestGel(from: 5600, to: 3200).family, .cto)
        // 5600K -> 3200K needs +134 mired: nearest is 1/2 CTO (137), as in the old app.
        XCTAssertEqual(ColourMaths.suggestGel(from: 5600, to: 3200).strength, "1/2")
        XCTAssertEqual(ColourMaths.suggestGel(from: 5600, to: 3200).residual, -3)
        XCTAssertEqual(ColourMaths.suggestGel(from: 3200, to: 5600).family, .ctb)
        XCTAssertEqual(ColourMaths.suggestGel(from: 5600, to: 5550).family, .none)
    }

    // MARK: Exposure

    func testNdFilters() {
        XCTAssertEqual(Exposure.stops(ndDensity: 0.9), 3, accuracy: 0.05)
        XCTAssertEqual(Exposure.stack(densities: [0.3, 0.6]).stops, 3, accuracy: 0.05)
        XCTAssertEqual(Exposure.ndDensity(stops: 1), 0.301, accuracy: 0.001)
    }

    func testFlicker() {
        XCTAssertTrue(Exposure.checkFlicker(shutter: 100, mainsHz: 50).safe)
        XCTAssertFalse(Exposure.checkFlicker(shutter: 125, mainsHz: 50).safe)
        XCTAssertEqual(Exposure.checkFlicker(shutter: 125, mainsHz: 50).nearestSafe, [100, 200])
        XCTAssertTrue(Exposure.checkFlicker(shutter: 120, mainsHz: 60).safe)
        XCTAssertEqual(Exposure.checkFlicker(shutter: 100, mainsHz: 50).nearestSafe, [100, 200])
    }

    func testEv100() {
        XCTAssertEqual(Exposure.ev100(lux: 2500), log2(2500 / 2.5), accuracy: 1e-9)
        XCTAssertEqual(Exposure.ev100(lux: 2500), 9.966, accuracy: 0.01)
    }

    func testAperture() {
        let bright = Exposure.aperture(lux: 8000, iso: 100, shutter: 50)
        XCTAssertEqual(bright.nearestStop, 8)
        XCTAssertEqual(bright.exact, 8, accuracy: 0.1)
        XCTAssertGreaterThan(Exposure.aperture(lux: 2000, iso: 200, shutter: 50).exact,
                             Exposure.aperture(lux: 2000, iso: 100, shutter: 50).exact)
    }

    // MARK: Power, cable, gobo

    func testPowerBudget() {
        let result = PowerBudget.compute(items: [.init(name: "Par", watts: 1000, quantity: 4)],
                                         voltage: 230, distroRatingAmps: 13)
        XCTAssertEqual(result.totalWatts, 4000)
        XCTAssertEqual(result.totalAmps, 17.39, accuracy: 0.01)
        XCTAssertTrue(result.overDistro)
        XCTAssertEqual(result.excessAmps ?? 0, 4.39, accuracy: 0.01)
        XCTAssertFalse(PowerBudget.compute(items: [], voltage: 230, distroRatingAmps: 32).overDistro)
    }

    func testCableDerating() {
        XCTAssertEqual(Cable.deratedCapacity(csaMm2: 2.5, ambient: 30), 25, accuracy: 0.01)
        XCTAssertLessThan(Cable.deratedCapacity(csaMm2: 2.5, ambient: 40), 25)
        XCTAssertEqual(Cable.derateFactor(ambient: 37.5), 0.91, accuracy: 0.001)
        let pick = Cable.recommend(amps: 20, ambient: 30)
        XCTAssertEqual(pick?.csaMm2, 2.5)
        XCTAssertNil(Cable.recommend(amps: 500, ambient: 30))
    }

    func testGoboSync() {
        XCTAssertEqual(GoboSync.rpm(bpm: 120, mode: .beat), 120)
        XCTAssertEqual(GoboSync.bpm(rpm: GoboSync.rpm(bpm: 120, mode: .bar), mode: .bar), 120)
    }

    // MARK: Sun

    private let london = Sun.Location(latitude: 51.5, longitude: -0.13, utcOffsetHours: 1)

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    func testSolsticeSunriseAndSunset() {
        let times = Sun.times(on: date("2026-06-21T12:00:00Z"), at: london)
        let sunrise = try! XCTUnwrap(times.sunrise), sunset = try! XCTUnwrap(times.sunset)
        // London midsummer: about 04:43 and 21:21 BST.
        XCTAssertEqual(sunrise / 60, 4.72, accuracy: 0.1)
        XCTAssertEqual(sunset / 60, 21.36, accuracy: 0.1)
        XCTAssertNotNil(times.goldenEvening)
        XCTAssertLessThan(times.blueMorning!.start, times.blueMorning!.end)
    }

    func testSunHighNearNoon() {
        let position = Sun.position(at: date("2026-06-21T11:00:00Z"), location: london)
        XCTAssertGreaterThan(position.elevation, 55)
        XCTAssertGreaterThan(position.azimuth, 120)
        XCTAssertLessThan(position.azimuth, 220)
    }

    func testPolarDayHasNoSunset() {
        let svalbard = Sun.Location(latitude: 78.2, longitude: 15.6, utcOffsetHours: 2)
        XCTAssertNil(Sun.times(on: date("2026-06-21T12:00:00Z"), at: svalbard).sunset)
    }

    // MARK: Units

    func testUnits() {
        let imperial = CompanionUnits(system: .imperial)
        XCTAssertEqual(imperial.distance.display(1), 3.2808, accuracy: 1e-4)
        XCTAssertEqual(imperial.distance.canonical(3.280839895), 1, accuracy: 1e-9)
        XCTAssertEqual(imperial.illuminance.display(10.763910417), 1, accuracy: 1e-9)
        XCTAssertEqual(CompanionUnits(system: .metric).distance.text(2.5), "2.5 m")
    }
}
