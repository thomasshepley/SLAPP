// Support/Changelog.swift
import Foundation

/// The app's CHANGELOG.md (bundled), parsed for the What's New screen.
/// Entries are "## <version> - <date> - <title>" followed by "- " bullets.
struct Changelog: Equatable {
    struct Entry: Equatable, Identifiable {
        let version: String
        let date: String
        let title: String
        /// Markdown, one per bullet.
        let notes: [String]
        var id: String { version }
    }

    let entries: [Entry]

    var latest: Entry? { entries.first }

    func entry(for version: String) -> Entry? {
        entries.first { $0.version == version }
    }

    init(markdown: String) {
        var entries: [Entry] = []
        var current: (version: String, date: String, title: String, notes: [String])?
        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                if let current { entries.append(Entry(version: current.version, date: current.date,
                                                      title: current.title, notes: current.notes)) }
                let parts = line.dropFirst(3).components(separatedBy: " - ")
                current = (parts[0].trimmingCharacters(in: .whitespaces),
                           parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "",
                           parts.count > 2 ? parts[2...].joined(separator: " - ").trimmingCharacters(in: .whitespaces) : "",
                           [])
            } else if line.hasPrefix("- "), current != nil {
                current?.notes.append(String(line.dropFirst(2)))
            }
        }
        if let current { entries.append(Entry(version: current.version, date: current.date,
                                              title: current.title, notes: current.notes)) }
        self.entries = entries
    }

    /// The changelog shipped in the app.
    static func bundled(in bundle: Bundle = .main) -> Changelog {
        guard let url = bundle.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return Changelog(markdown: "") }
        return Changelog(markdown: text)
    }

    /// Plain-text release notes for one entry (TestFlight's "What to Test").
    static func plainNotes(_ entry: Entry) -> String {
        let header = entry.title.isEmpty ? entry.version : "\(entry.version) - \(entry.title)"
        return ([header] + entry.notes.map { "- " + $0.replacingOccurrences(of: "**", with: "") })
            .joined(separator: "\n")
    }
}
