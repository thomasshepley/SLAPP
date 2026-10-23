// Titan/TitanHandles.swift
import Foundation

/// One playback handle from GET /titan/handles/Playbacks.
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
}

enum TitanHandlesParser {
    static func parse(_ data: Data) -> [PlaybackHandleState]? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return array.map { handle in
            var userNumber = intValue(value(in: handle, key: "userNumber"))
            if userNumber == nil, let properties = handle["properties"] as? [[String: Any]] {
                for property in properties {
                    if let key = property["Key"] as? String, key.caseInsensitiveCompare("userNumber") == .orderedSame {
                        userNumber = intValue(property["Value"])
                    }
                }
            }
            return PlaybackHandleState(
                titanId: intValue(value(in: handle, key: "titanId")),
                userNumber: userNumber,
                active: boolValue(value(in: handle, key: "active")) ?? false,
                legend: value(in: handle, key: "legend") as? String ?? ""
            )
        }
    }

    /// User numbers of active playbacks, or nil if Titan didn't report any
    /// user numbers (then live key state can't work and the UI says so).
    static func activeUserNumbers(_ handles: [PlaybackHandleState]) -> Set<Int>? {
        guard handles.isEmpty || handles.contains(where: { $0.userNumber != nil }) else { return nil }
        return Set(handles.filter(\.active).compactMap(\.userNumber))
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
