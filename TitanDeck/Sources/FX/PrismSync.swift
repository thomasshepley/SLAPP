// FX/PrismSync.swift
import Foundation

/// Sync with Prism (0.39): the FX Library takes in what Prism has, read by
/// TitanDeck Host from Prism's files on the PC. Each clip's bank is its
/// Folder in Titan and its place in the bank its File (from the first
/// numbers set in Prism Setup, unless the media folder's names carry
/// numbers). Clips already in the library keep their names, categories and
/// notes; only their Prism numbers follow Prism. Pure, so it's tested.
enum PrismSync {
    struct Settings: Codable, Equatable {
        /// A folder or file on the PC to read instead of looking for Prism's.
        var folder = ""
        /// Titan's Folder for Prism's first bank, and File for a bank's first clip.
        var firstFolder = 1
        var firstFile = 1

        static let key = "fx.prismSync"

        static func load(_ defaults: UserDefaults = .standard) -> Settings {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
        }

        func save(_ defaults: UserDefaults = .standard) {
            if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
        }
    }

    struct Report: Equatable {
        var clips = 0
        var added = 0
        var renumbered = 0
        var linked = 0
        var gone = 0

        var text: String {
            var parts = ["Prism has \(clips) clip\(clips == 1 ? "" : "s")"]
            if added > 0 { parts.append("\(added) new") }
            if linked > 0 { parts.append("\(linked) matched to clips you had") }
            if renumbered > 0 { parts.append("\(renumbered) with new Folder / File numbers") }
            if gone > 0 { parts.append("\(gone) no longer in Prism") }
            if added + linked + renumbered + gone == 0 { parts.append("the library was up to date") }
            return parts.joined(separator: ", ") + "."
        }
    }

    static func folder(_ bank: HostPrismBank, _ settings: Settings) -> Int { bank.number ?? bank.index + settings.firstFolder }
    static func file(_ clip: HostPrismClip, _ settings: Settings) -> Int { clip.number ?? clip.index + settings.firstFile }

    /// The library with Prism's clips in it.
    static func merge(_ banks: [HostPrismBank], into items: [FXItem], settings: Settings,
                      now: Date = Date(), newID: () -> UUID = UUID.init) -> (items: [FXItem], report: Report) {
        var items = items
        var report = Report()
        var matched = Set<UUID>()
        for bank in banks {
            for clip in bank.clips {
                report.clips += 1
                let folder = folder(bank, settings)
                let file = file(clip, settings)
                let path = clip.path.map(normal)
                let stem = clip.path.map(stem) ?? clip.name
                if let i = match(clip: clip, path: path, stem: stem, folder: folder, file: file, items: items, matched: matched) {
                    matched.insert(items[i].id)
                    var item = items[i]
                    if item.prismPath == nil { report.linked += 1 }
                    if item.prismFolder != nil, item.prismFolder != folder || item.prismFile != file { report.renumbered += 1 }
                    item.prismFolder = folder
                    item.prismFile = file
                    item.prismBank = bank.name
                    item.prismPath = clip.path
                    item.prismMissing = nil
                    items[i] = item
                } else {
                    let title = clip.name.replacingOccurrences(of: "_", with: " ")
                    let guess = FXItem.Category.guess(from: clip.name)
                    let item = FXItem(id: newID(), title: title,
                                      category: guess == .other ? .guess(from: bank.name) : guess,
                                      fileName: "", kind: FXItem.kind(forExtension: extensionOf(clip.path ?? "")) ?? .video,
                                      notes: "", added: now, prismFolder: folder, prismFile: file,
                                      prismBank: bank.name, prismPath: clip.path)
                    matched.insert(item.id)
                    items.append(item)
                    report.added += 1
                }
            }
        }
        for i in items.indices where items[i].prismPath != nil && !matched.contains(items[i].id) {
            if items[i].prismMissing != true { report.gone += 1 }
            items[i].prismMissing = true
        }
        return (items, report)
    }

    /// The library entry for a clip: the same file on the PC, else one of
    /// yours that's the same clip (its name, or the file you sent) and isn't
    /// tied to another Prism clip.
    private static func match(clip: HostPrismClip, path: String?, stem: String, folder: Int, file: Int,
                              items: [FXItem], matched: Set<UUID>) -> Int? {
        let open = items.indices.filter { !matched.contains(items[$0].id) }
        if let path, let i = open.first(where: { items[$0].prismPath.map(normal) == path }) { return i }
        let names = [clip.name, stem].map { $0.lowercased() }
        let unlinked = open.filter { items[$0].prismPath == nil }
        func sameClip(_ item: FXItem) -> Bool {
            names.contains(item.title.lowercased()) || (!item.fileName.isEmpty && names.contains(Self.stem(item.fileName).lowercased()))
        }
        if let i = unlinked.first(where: { items[$0].prismFolder == folder && items[$0].prismFile == file && sameClip(items[$0]) }) { return i }
        return unlinked.first { sameClip(items[$0]) }
    }

    private static func normal(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/").lowercased()
    }

    private static func extensionOf(_ path: String) -> String {
        (path.replacingOccurrences(of: "\\", with: "/") as NSString).pathExtension
    }

    /// "D:\Media\fire_big.mov" -> "fire_big".
    static func stem(_ path: String) -> String {
        let name = path.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? path
        return (name as NSString).deletingPathExtension
    }
}
