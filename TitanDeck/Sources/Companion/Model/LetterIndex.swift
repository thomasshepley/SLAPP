// Companion/Model/LetterIndex.swift
import Foundation

/// A-Z grouping for long lists (manufacturers), and the letter under a finger
/// on the side index.
enum LetterIndex {
    /// A to Z, then # for anything starting with a digit or symbol.
    static let alphabet: [String] = (65 ... 90).map { String(UnicodeScalar($0)) } + ["#"]

    /// "Élation" -> "E", "3Dlight" -> "#".
    static func letter(for name: String) -> String {
        let folded = name.trimmingCharacters(in: .whitespaces)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
            .uppercased()
        guard let first = folded.unicodeScalars.first, (65 ... 90).contains(first.value) else { return "#" }
        return String(first)
    }

    /// Names grouped by first letter, A-Z then #, each group sorted.
    static func sections(_ names: [String]) -> [(letter: String, names: [String])] {
        let grouped = Dictionary(grouping: names, by: letter(for:))
        return alphabet.compactMap { letter in
            grouped[letter].map { (letter, $0.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) }
        }
    }

    /// The letter at a point on the index strip (0 top, 1 bottom), snapped to
    /// the nearest letter that has entries.
    static func letter(atFraction fraction: Double, available: [String]) -> String? {
        guard !available.isEmpty else { return nil }
        let clamped = min(1, max(0, fraction))
        let index = min(alphabet.count - 1, Int(clamped * Double(alphabet.count)))
        let target = alphabet[index]
        if available.contains(target) { return target }
        // Nearest available letter by position in the alphabet.
        let positions = available.compactMap { letter in alphabet.firstIndex(of: letter).map { (letter, $0) } }
        return positions.min { abs($0.1 - index) < abs($1.1 - index) }?.0
    }
}
