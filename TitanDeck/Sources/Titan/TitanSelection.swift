// Titan/TitanSelection.swift
import Foundation

/// Reads what's selected in Titan, and where a fixture is patched, out of
/// Titan's answers. The API docs only give the types ("List`1",
/// "DmxAssignment"), not the JSON, so these accept every shape that's likely
/// and the raw text is logged for checking on a real console.
enum TitanSelectionParser {
    /// Titan ids from `Selection/Context/.../GetAllSelectedFixtureIds`:
    /// `[1689, 1690]`, `[{"titanId":1689}]`, `{"value":[...]}` or "1689,1690".
    /// An empty list means nothing's selected; nil means it couldn't be read.
    static func titanIds(from data: Data) -> [Int]? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return ids(fromText: String(decoding: data, as: UTF8.self))
        }
        return ids(from: json)
    }

    /// titanId -> user number, from `/titan/handles/Fixtures`.
    static func userNumbers(_ handles: [PlaybackHandleState]) -> [Int: Int] {
        var map: [Int: Int] = [:]
        for handle in handles {
            if let id = handle.titanId, let number = handle.userNumber { map[id] = number }
        }
        return map
    }

    private static func ids(from json: Any) -> [Int]? {
        switch json {
        case let array as [Any]:
            return array.compactMap(id(of:))
        case let object as [String: Any]:
            for key in ["value", "Value", "items", "Items", "ids", "titanIds", "result", "Result"] {
                if let inner = object[key] { return ids(from: inner) }
            }
            return id(of: object).map { [$0] }
        case let text as String:
            return ids(fromText: text)
        case let number as NSNumber:
            return [number.intValue]
        default:
            return nil
        }
    }

    private static func id(of item: Any) -> Int? {
        if let number = item as? NSNumber { return number.intValue }
        if let text = item as? String { return Int(text.trimmingCharacters(in: .whitespaces)) }
        if let object = item as? [String: Any] {
            for key in ["titanId", "TitanId", "id", "Id", "ID", "hashCode"] {
                if let value = object[key], let number = id(of: value) { return number }
            }
        }
        return nil
    }

    private static func ids(fromText text: String) -> [Int]? {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r\t[]"))
        if trimmed.isEmpty { return [] }
        let parts = trimmed.split { ",; \n".contains($0) }
        let numbers = parts.compactMap { Int($0) }
        return numbers.count == parts.count ? numbers : nil
    }
}

/// Where a fixture is patched: universe and DMX address, both 1-based.
struct DmxAddress: Codable, Hashable {
    var universe: Int
    var address: Int

    /// Titan's DmxAssignment, whatever shape it comes in: an object with
    /// universe and address fields, text like "2.101", "2/101", "2:101" or
    /// "U2 101", or one absolute channel number (513 is universe 2, address 1).
    static func parse(_ data: Data) -> DmxAddress? {
        let text = String(decoding: data, as: UTF8.self)
        // "2.101" unquoted reads as the number 2.101 in JSON; keep it as text.
        if let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
           !(json is NSNumber && text.contains(".")) {
            return parse(json: json)
        }
        return parse(text: text)
    }

    private static func parse(json: Any) -> DmxAddress? {
        switch json {
        case let object as [String: Any]:
            var universe: Int?
            var address: Int?
            for (key, value) in object {
                let name = key.lowercased()
                let number = (value as? NSNumber)?.intValue ?? (value as? String).flatMap { Int($0) }
                if name.contains("univ") { universe = number ?? universe }
                else if name.contains("addr") || name.contains("channel") || name == "start" || name == "dmx" {
                    address = number ?? address
                }
            }
            if let address { return make(universe: universe ?? 1, address: address) }
            for key in ["value", "Value", "dmxAssignment", "DmxAssignment"] {
                if let inner = object[key] { return parse(json: inner) }
            }
            return nil
        case let text as String:
            return parse(text: text)
        case let number as NSNumber:
            return absolute(number.intValue)
        default:
            return nil
        }
    }

    private static func parse(text: String) -> DmxAddress? {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r\t"))
        let numbers = trimmed.split { !$0.isNumber }.compactMap { Int($0) }
        switch numbers.count {
        case 1: return absolute(numbers[0])
        case 2: return make(universe: numbers[0], address: numbers[1])
        default: return nil
        }
    }

    private static func absolute(_ channel: Int) -> DmxAddress? {
        guard channel >= 1 else { return nil }
        return make(universe: (channel - 1) / 512 + 1, address: (channel - 1) % 512 + 1)
    }

    private static func make(universe: Int, address: Int) -> DmxAddress? {
        guard (1 ... 63999).contains(universe), (1 ... 512).contains(address) else { return nil }
        return DmxAddress(universe: universe, address: address)
    }
}
