// Companion/Calc/Sun.swift
import Foundation

/// Sunrise, sunset, golden and blue hour, and the sun's position, from the
/// NOAA solar position algorithm. Accurate to well within a minute at normal
/// latitudes. Times are minutes from local midnight, using the location's UTC
/// offset, so they read as that location's wall-clock time.
enum Sun {
    struct Location: Equatable {
        var latitude: Double
        var longitude: Double
        /// Hours from UTC at the location, e.g. 1 for BST.
        var utcOffsetHours: Double
    }

    struct Window: Equatable {
        let start: Double
        let end: Double
    }

    struct Times: Equatable {
        /// Nil when the sun doesn't rise or set that day (polar).
        let sunrise: Double?
        let sunset: Double?
        let solarNoon: Double
        let goldenMorning: Window?
        let goldenEvening: Window?
        let blueMorning: Window?
        let blueEvening: Window?
    }

    struct Position: Equatable {
        /// Compass bearing: 0 north, 90 east.
        let azimuth: Double
        /// 0 horizon, 90 overhead.
        let elevation: Double
    }

    static func times(on date: Date, at location: Location) -> Times {
        let (decl, eqTime) = solarParameters(date)
        let noon = solarNoon(location, eqTime)
        func at(_ elevation: Double, morning: Bool) -> Double? {
            let lat = radians(location.latitude), d = radians(decl)
            let cosH = (sin(radians(elevation)) - sin(lat) * sin(d)) / (cos(lat) * cos(d))
            guard cosH >= -1, cosH <= 1 else { return nil }
            let offset = degrees(acos(cosH)) / 15 * 60
            return morning ? noon - offset : noon + offset
        }
        func window(_ a: Double?, _ b: Double?) -> Window? {
            guard let a, let b else { return nil }
            return Window(start: a, end: b)
        }
        let sunrise = at(-0.833, morning: true)
        let sunset = at(-0.833, morning: false)
        return Times(sunrise: sunrise, sunset: sunset, solarNoon: noon,
                     goldenMorning: window(sunrise, at(6, morning: true)),
                     goldenEvening: window(at(6, morning: false), sunset),
                     blueMorning: window(at(-6, morning: true), at(-4, morning: true)),
                     blueEvening: window(at(-4, morning: false), at(-6, morning: false)))
    }

    /// Position at an instant. Depends only on the absolute time, latitude and
    /// longitude - the UTC offset isn't needed.
    static func position(at date: Date, location: Location) -> Position {
        let (decl, eqTime) = solarParameters(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let minutes = Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0) + Double(parts.second ?? 0) / 60
        let trueSolarTime = mod(minutes + eqTime + 4 * location.longitude, 1440)
        let hourAngle = radians(trueSolarTime / 4 - 180)
        let lat = radians(location.latitude), d = radians(decl)
        let elevation = degrees(asin(sin(lat) * sin(d) + cos(lat) * cos(d) * cos(hourAngle)))
        let azimuth = degrees(atan2(sin(hourAngle), cos(hourAngle) * sin(lat) - tan(d) * cos(lat)))
        return Position(azimuth: mod(azimuth + 180, 360), elevation: elevation)
    }

    /// The point `metres` away along a compass bearing, for drawing the sun's
    /// direction on a map (great-circle, fine at these distances).
    static func destination(latitude: Double, longitude: Double, bearing: Double, metres: Double)
        -> (latitude: Double, longitude: Double) {
        let earthRadius = 6_371_000.0
        let angular = metres / earthRadius
        let lat1 = radians(latitude), lon1 = radians(longitude), theta = radians(bearing)
        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(angular) * cos(lat1), cos(angular) - sin(lat1) * sin(lat2))
        return (degrees(lat2), mod(degrees(lon2) + 540, 360) - 180)
    }

    // MARK: - NOAA

    private static func solarParameters(_ date: Date) -> (declination: Double, equationOfTime: Double) {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (julianDay - 2_451_545) / 36_525
        let l0 = mod(280.46646 + t * (36_000.76983 + t * 0.0003032), 360)
        let m = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let mr = radians(m)
        let c = sin(mr) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mr) * (0.019993 - 0.000101 * t)
            + sin(3 * mr) * 0.000289
        let omega = 125.04 - 1934.136 * t
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(radians(omega))
        let epsilon0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let epsilon = epsilon0 + 0.00256 * cos(radians(omega))
        let declination = degrees(asin(sin(radians(epsilon)) * sin(radians(lambda))))
        let y = pow(tan(radians(epsilon / 2)), 2)
        let l0r = radians(l0)
        let eqTime = 4 * degrees(y * sin(2 * l0r) - 2 * e * sin(mr) + 4 * e * y * sin(mr) * cos(2 * l0r)
            - 0.5 * y * y * sin(4 * l0r) - 1.25 * e * e * sin(2 * mr))
        return (declination, eqTime)
    }

    private static func solarNoon(_ location: Location, _ eqTime: Double) -> Double {
        720 - 4 * location.longitude - eqTime + location.utcOffsetHours * 60
    }

    private static func radians(_ d: Double) -> Double { d * .pi / 180 }
    private static func degrees(_ r: Double) -> Double { r * 180 / .pi }
    private static func mod(_ n: Double, _ m: Double) -> Double { (n.truncatingRemainder(dividingBy: m) + m).truncatingRemainder(dividingBy: m) }
}
