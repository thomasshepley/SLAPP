// App/DeckProgrammer.swift
import Foundation

/// What the deck itself has set in its WebAPI user's programmer, fixture by
/// fixture (0.44.1): levels from the keypad ("@ 50"), the +/- keys and FX,
/// and CCT palettes. Titan's WebAPI can't read a level or colour back, so
/// when a fixture is selected again this is how the deck still knows them
/// (a live sACN level wins over it). CLEAR empties the programmer, and this
/// with it. Pure, so it's tested.
struct DeckProgrammer: Equatable {
    private(set) var levels: [Int: Double] = [:]
    private(set) var kelvins: [Int: Int] = [:]

    mutating func setLevel(_ level: Double, for fixtures: [Int]) {
        let level = min(max(level, 0), 1)
        for fixture in fixtures { levels[fixture] = level }
    }

    mutating func setKelvin(_ kelvin: Int, for fixtures: [Int]) {
        for fixture in fixtures { kelvins[fixture] = kelvin }
    }

    /// The level every one of these fixtures has, or nil if any differs or isn't known.
    func level(for fixtures: [Int]) -> Double? {
        Self.common(fixtures.map { levels[$0] })
    }

    func kelvin(for fixtures: [Int]) -> Int? {
        Self.common(fixtures.map { kelvins[$0] })
    }

    mutating func clear() {
        levels = [:]
        kelvins = [:]
    }

    private static func common<T: Equatable>(_ values: [T?]) -> T? {
        guard let first = values.first, let value = first, values.allSatisfy({ $0 == value }) else { return nil }
        return value
    }
}
