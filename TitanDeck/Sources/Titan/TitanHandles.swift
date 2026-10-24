// Titan/TitanHandles.swift
import Foundation

/// One handle from GET /titan/handles/<group> (Playbacks, Colours,
/// Workspaces...).
///
/// Documented response shape (Titan v19.2 API intro):
/// [{"handleLocation":{"group":"Playbacks","index":0,"page":0},
///   "properties":[{"Key":"lockState","Value":"Unlocked"}],
///   "titanId":1689, "type":"playbackHandle", "Active":false, "Legend":""}]
/// The docs don't show where (or if) the user number appears, so the parser
/// looks for it at the top level and in `properties`, under any casing.
struct PlaybackHandleState: Equatable {
    var titanId: Int?
    var userNumber: Int?
    var active: Bool
    var legend: String
    /// handleLocation: page and position on it, both 0-based.
    var page: Int? = nil
    var index: Int? = nil
}

enum TitanHandlesParser {
    static func parse(_ data: Data) -> [PlaybackHandleState]? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return array.map { handle in
            var userNumber = userNumberValue(value(in: handle, key: "userNumber"))
            if userNumber == nil, let properties = handle["properties"] as? [[String: Any]] {
                for property in properties {
                    if let key = property["Key"] as? String, key.caseInsensitiveCompare("userNumber") == .orderedSame {
                        userNumber = userNumberValue(property["Value"])
                    }
                }
            }
            let location = value(in: handle, key: "handleLocation") as? [String: Any] ?? [:]
            return PlaybackHandleState(
                titanId: intValue(value(in: handle, key: "titanId")),
                userNumber: userNumber,
                active: boolValue(value(in: handle, key: "active")) ?? false,
                legend: value(in: handle, key: "legend") as? String ?? "",
                page: intValue(self.value(in: location, key: "page")),
                index: intValue(self.value(in: location, key: "index"))
            )
        }
    }

    /// Legends by user number (workspace names, for instance).
    static func legendsByUserNumber(_ handles: [PlaybackHandleState]) -> [Int: String] {
        var names: [Int: String] = [:]
        for handle in handles {
            guard let number = handle.userNumber, !handle.legend.isEmpty else { continue }
            names[number] = handle.legend
        }
        return names
    }

    /// User numbers of active playbacks, or nil if Titan didn't report any
    /// user numbers (then live key state can't work and the UI says so).
    static func activeUserNumbers(_ handles: [PlaybackHandleState]) -> Set<Int>? {
        guard handles.isEmpty || handles.contains(where: { $0.userNumber != nil }) else { return nil }
        return Set(handles.filter(\.active).compactMap(\.userNumber))
    }

    /// A user number as a plain number, or (as some Titan versions send it)
    /// an object such as {"userNumbers":[3]} or {"hashCode":3}.
    private static func userNumberValue(_ raw: Any?) -> Int? {
        if let number = intValue(raw) { return number }
        if let object = raw as? [String: Any] {
            for key in ["userNumbers", "userNumber", "number", "value", "hashCode"] {
                let inner = value(in: object, key: key)
                if let list = inner as? [Any], let first = list.first, let number = intValue(first) { return number }
                if let number = intValue(inner) { return number }
            }
        }
        if let list = raw as? [Any], let first = list.first { return intValue(first) }
        return nil
    }

    private static func value(in dictionary: [String: Any], key: String) -> Any? {
        dictionary.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int: return int
        case let double as Double: return Int(exactly: double.rounded())
        case let string as String: return Int(string.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool: return bool
        case let string as String: return string.lowercased() == "true"
        case let int as Int: return int != 0
        default: return nil
        }
    }
}

/// Finds the colour palette for a colour temperature by its legend: "3200K",
/// "3200 K", "Tungsten 3200K" and "3200" all match 3200, "13200K" doesn't.
enum TitanPaletteMatch {
    static func palette(for kelvin: Int, in palettes: [PlaybackHandleState]) -> PlaybackHandleState? {
        let withK = palettes.first { matches($0.legend, kelvin, needK: true) }
        return withK ?? palettes.first { matches($0.legend, kelvin, needK: false) }
    }

    private static func matches(_ legend: String, _ kelvin: Int, needK: Bool) -> Bool {
        let pattern = needK ? "(?<![0-9])\(kelvin)\\s*[kK](?![a-zA-Z])" : "(?<![0-9.])\(kelvin)(?![0-9])"
        return legend.range(of: pattern, options: .regularExpression) != nil
    }
}
