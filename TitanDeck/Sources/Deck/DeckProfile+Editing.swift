// Deck/DeckProfile+Editing.swift
import Foundation

/// Editing operations used by the deck editor. Kept on the model (not in the
/// views) so they can be unit tested. Every edit clears `isBuiltInDefault`, so
/// a hand-edited profile is never re-flowed for a different deck size.
extension DeckProfile {
    /// Columns to lay the editor grid out in, matching the physical deck.
    static func gridColumns(forKeyCount count: Int) -> Int {
        switch count {
        case 32: return 8   // XL, Module 32
        case 15: return 5   // MK.2, Module 15
        case 8: return 4    // Neo, Plus
        case 6: return 3    // Mini, Module 6
        default: return max(1, Int(Double(count).squareRoot().rounded(.up)))
        }
    }

    /// Columns as you look at the deck (portrait decks are narrower).
    var gridColumns: Int {
        geometry.logicalColumns
    }

    /// Appends a blank page with a "next page" key in the last position, so the
    /// new page is never a dead end. Returns the new page's index.
    @discardableResult
    mutating func addPage(named name: String? = nil) -> Int {
        let navKey = KeyDefinition(index: max(keyCount - 1, 0), label: "Next\npage", colorHex: Self.pageColor,
                                   sfSymbol: "arrow.right.square", action: .nextPage)
        pages.append(DeckPage(name: name ?? "Page \(pages.count + 1)", keys: [navKey]))
        isBuiltInDefault = false
        return pages.count - 1
    }

    /// Copies a page (with fresh ids) to just after the original. Returns the copy's index.
    @discardableResult
    mutating func duplicatePage(at index: Int) -> Int? {
        guard pages.indices.contains(index) else { return nil }
        var copy = pages[index]
        copy.id = UUID()
        copy.name += " copy"
        copy.keys = copy.keys.map { key in
            var key = key
            key.id = UUID()
            return key
        }
        let newIndex = index + 1
        pages.insert(copy, at: newIndex)
        // Pages from newIndex on moved up one - the copy's own links included.
        remapPageLinks { $0 >= newIndex ? $0 + 1 : $0 }
        isBuiltInDefault = false
        return newIndex
    }

    /// Removes a page, keeping at least one. "Go to page" keys pointing at the
    /// removed page become "next page"; later page numbers shift down.
    mutating func removePage(at index: Int) {
        guard pages.count > 1, pages.indices.contains(index) else { return }
        pages.remove(at: index)
        remapPageLinks { target in
            if target == index { return nil }
            return target > index ? target - 1 : target
        }
        isBuiltInDefault = false
    }

    /// Moves a page, keeping "go to page" keys pointing at the same pages.
    mutating func movePage(from source: Int, to destination: Int) {
        guard pages.indices.contains(source), pages.indices.contains(destination), source != destination else { return }
        var order = Array(pages.indices)
        order.insert(order.remove(at: source), at: destination)
        // order[newIndex] == oldIndex
        var newIndexFor = [Int: Int]()
        for (newIndex, oldIndex) in order.enumerated() { newIndexFor[oldIndex] = newIndex }
        pages = order.map { pages[$0] }
        remapPageLinks { newIndexFor[$0] }
        isBuiltInDefault = false
    }

    mutating func renamePage(at index: Int, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pages.indices.contains(index), !trimmed.isEmpty else { return }
        pages[index].name = trimmed
        isBuiltInDefault = false
    }

    /// Inserts or replaces the key at `key.index` on a page.
    mutating func setKey(_ key: KeyDefinition, onPage page: Int) {
        guard pages.indices.contains(page), key.index >= 0, key.index < keyCount else { return }
        var keys = pages[page].keys.filter { $0.index != key.index }
        keys.append(key)
        pages[page].keys = keys.sorted { $0.index < $1.index }
        isBuiltInDefault = false
    }

    mutating func clearKey(at keyIndex: Int, onPage page: Int) {
        guard pages.indices.contains(page) else { return }
        pages[page].keys.removeAll { $0.index == keyIndex }
        isBuiltInDefault = false
    }

    /// Rewrites every `.switchPage(n)` through `map`. A nil result means the
    /// target page has gone, so the key falls back to "next page".
    private mutating func remapPageLinks(_ map: (Int) -> Int?) {
        for p in pages.indices {
            for k in pages[p].keys.indices {
                if case .switchPage(let target) = pages[p].keys[k].action {
                    pages[p].keys[k].action = map(target).map { .switchPage($0) } ?? .nextPage
                }
            }
        }
    }
}
