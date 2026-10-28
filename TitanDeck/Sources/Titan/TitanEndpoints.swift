// Titan/TitanEndpoints.swift
import Foundation

/// URL builders for the Titan WebAPI (HTTP, port 4430).
///
/// Paths and parameter names checked against the Avolites Titan v19.2 API docs
/// (https://api.avolites.com/19.2/api/). Handle parameters take a suffix saying
/// how the handle is identified - we always use the playback's user number, e.g.
/// `handle_userNumber=6`. Levels use `level_level` (absolute) - `level_leveldelta`
/// would be relative. Older Titan versions (pre-v12) use a different syntax.
enum TitanEndpoints {
    static let defaultPort = 4430
    /// IncrementDimmer is Titan's encoder wheel, not a percentage: on Titan 19
    /// a value of 10 moved a fixture about 0.25%, i.e. one step is 1/4096 of
    /// full. So a percentage is sent as percent x 40.96 steps.
    static let dimmerStepsPerPercent = 40.96

    /// The wheel accelerates when turned fast (409.6 steps in one go moved a
    /// fixture about 60%, not 10%), and timeDelta is how long the turn took.
    /// 10 steps in a second was linear, so a nudge is "turned" at that speed.
    static func wheelSeconds(steps: Double) -> Double {
        max(1, (abs(steps) / 10).rounded(.up))
    }
    /// Titan's WebAPI through TitanDeck Host (Host 0.9+), which logs every call.
    static let viaHostPort = 4436
    static let scriptRoot = "/titan/script/2/"

    /// Full URL for an action, or nil for local-only actions or an unusable host.
    static func url(for action: TitanAction, host: String, port: Int = defaultPort) -> URL? {
        switch action {
        case .playbackGo(let n):
            return script(host, port, "Playbacks/FirePlaybackAtLevel", [
                ("handle_userNumber", "\(n)"),
                ("level_level", "1"),
                ("alwaysRefire", "false"),
            ])
        case .playbackRelease(let n):
            return script(host, port, "Playbacks/ReleasePlayback", [
                ("handle_userNumber", "\(n)"),
                ("fadeTime", "0"),
                ("useMasterReleaseTime", "true"),
            ])
        case .setFaderLevel(let n, let level):
            return script(host, port, "Playbacks/SetPlaybackLevel", [
                ("srcHandle_userNumber", "\(n)"),
                ("level_level", format(level: level)),
            ])
        case .runMacro(let id):
            return script(host, port, "Macros/Run", [("macroId", id)])
        case .raw(let path):
            let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
            return URL(string: "http://\(authority(host, port))\(scriptRoot)\(trimmed)")
        case .keypadDigit(let digit):
            return script(host, port, "Command/AppendStringAndPreview", [("text", "\(min(max(digit, 0), 9))")])
        case .keypadAt:
            return script(host, port, "Command/AppendStringAndPreview", [("text", "@")])
        case .keypadThro:
            // Only when the keys can't be typed on the desk: ">" is Titan's
            // command-line Thro as far as we know (unconfirmed).
            return script(host, port, "Command/AppendStringAndPreview", [("text", ">")])
        case .keypadExit:
            return script(host, port, "Menu/ExitRootOrLatched", [])
        case .adjustIntensity(let percent):
            // Wheel steps (see dimmerStepsPerPercent), "turned" slowly enough not to accelerate.
            let steps = percent * dimmerStepsPerPercent
            return script(host, port, "Programmer/Editor/Fixtures/IncrementDimmer", [
                ("value", format(number: steps)),
                ("timeDelta", format(number: wheelSeconds(steps: steps))),
                ("shiftEnabled", "false"),
            ])
        case .fireHandle(let id):
            return script(host, port, "Playbacks/FirePlaybackAtLevel", [
                ("handle_titanId", "\(id)"),
                ("level_level", "1"),
                ("alwaysRefire", "false"),
            ])
        case .releaseHandle(let id):
            return script(host, port, "Playbacks/ReleasePlayback", [
                ("handle_titanId", "\(id)"),
                ("fadeTime", "0"),
                ("useMasterReleaseTime", "true"),
            ])
        case .recallWorkspace(let n):
            return script(host, port, "Workspace/Apply", [("handle_userNumber", "\(n)")])
        case .keypadEnter, .keypadClear, .colourTemperature, .setCueFade, .dimmerFlash:
            return nil   // several requests - TitanClient runs them
        case .switchPage, .openSettings, .nextPage, .previousPage, .mainMenu, .colourPresets,
             .cueGo, .cueFade, .connectCue, .deckChoice, .flashSelection:
            return nil
        }
    }

    /// Palette/ApplyPalette on the selection, without the palette's own times.
    static func applyPaletteURL(titanId: Int, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Palette/ApplyPalette", [("handle_titanId", "\(titanId)"), ("usePaletteTimes", "false")])
    }

    // MARK: Cue fades (experimental: the write's body format isn't documented)

    /// Makes cue 1 of a playback the editor's cue, so its times can be set.
    static func selectFirstCueURL(titanId: Int, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Playbacks/Editor/CueSelection/SelectCueByNumber", [
            ("handle_titanId", "\(titanId)"), ("cueNumber", "1"),
        ])
    }

    /// Loads a playback into the editor, as Titan's own cue-time macros do
    /// first (`ActionScript.SetProperty("Playbacks.Editor.SelectedPlayback",
    /// handle)`): the editor's cue selection and times all relate to it.
    static func selectEditorPlaybackURL(titanId: Int, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "ActionScript/SetProperty", [("id", "Playbacks.Editor.SelectedPlayback"), ("value_titanId", "\(titanId)")])
    }

    /// The same through Titan's documented call for the selected playbacks,
    /// for a Titan that won't take the handle above.
    static func setSelectedPlaybacksURL(titanId: Int, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Playbacks/Editor/SetSelectedPlaybacks", [("handles_handleList", "\(titanId)")])
    }

    /// The desk's Edit Times for a playback: fills the times menu for its cue
    /// type and makes it the playback whose times are being edited.
    static func fillTimesURL(titanId: Int, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Playbacks/TimesEdit/FillTimes", [("handle_titanId", "\(titanId)")])
    }

    /// The playback loaded into the editor (read to say what Titan was editing).
    static func editorPlaybackURL(host: String, port: Int = defaultPort) -> URL? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else { return nil }
        return URL(string: "http://\(authority(host, port))/titan/get/2/Playbacks/Editor/SelectedPlayback")
    }

    /// Sets a time property in seconds, typed as a time the way macros write
    /// `time:3` and Titan's own time parameters take `fadeTime=5`.
    static func setPropertyTimeURL(id: String, seconds: Double, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "ActionScript/SetProperty", [("id", id), ("value_time", format(number: seconds))])
    }

    /// Sets a Titan property from a number in the URL, the way Titan's own
    /// macros do (`ActionScript.SetProperty.Float`). Titan converts it to the
    /// property's type: the cue times' AcwTimeSpan takes seconds, as in
    /// `Programmer/Editor/Fixtures/Release?fadeTime=5`.
    static func setPropertyFloatURL(id: String, value: Double, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "ActionScript/SetProperty/Float", [("id", id), ("value", format(number: value))])
    }

    /// Sets a Titan property from text, Titan converting it to the property's
    /// type (`ActionScript.SetProperty`, as macros set a legend).
    static func setPropertyURL(id: String, value: String, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "ActionScript/SetProperty", [("id", id), ("value", value)])
    }

    /// Titan's property id for the selected cue's fade in or out time.
    static func cueFadePropertyID(fadeOut: Bool) -> String {
        "Playbacks.Editor.Times.\(fadeOut ? "CueFadeOutTime" : "CueFadeInTime")"
    }

    /// The selected cue's fade in or out time, read with GET and written with
    /// POST (the value as the body).
    static func cueFadePropertyURL(fadeOut: Bool, write: Bool, host: String, port: Int = defaultPort) -> URL? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else { return nil }
        let verb = write ? "set" : "get"
        return URL(string: "http://\(authority(host, port))/titan/\(verb)/2/Playbacks/Editor/Times/\(fadeOut ? "CueFadeOutTime" : "CueFadeInTime")")
    }

    // MARK: Flash (hold to 0%)

    /// The selection's dimmer to a level in percent (no fade: Titan's call has no time).
    static func setDimmerLevelURL(percent: Double, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Programmer/Editor/Fixtures/SetDimmerLevel", [("level", format(number: percent))])
    }

    /// Titan's own flash to zero for the selected fixtures, and the end of it:
    /// ClearFlash puts them back exactly as they were (nothing is released).
    static func flashOutURL(host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Programmer/Editor/Fixtures/FlashOut", [])
    }

    static func clearFlashURL(host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Programmer/Editor/Fixtures/ClearFlash", [])
    }

    /// Every selected fixture (as Titan ids), ignoring pattern select. On the
    /// UI WebAPI (desk link) this is the operator's selection; on 4430 it's
    /// the WebAPI user's own.
    static func selectedFixtureIdsURL(context: String = "Global", host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Selection/Context/\(context)/GetAllSelectedFixtureIds", [])
    }

    /// The desk's first Clear: the selection only, every programmer left as it
    /// is. On the UI WebAPI (desk link) that's the operator's own selection.
    /// `everyUser`: every user's selection, the desk's included (Titan 19,
    /// where the 4430 WebAPI is a separate user and CITP only listens).
    static func clearDeskSelectionURL(host: String, port: Int = defaultPort, everyUser: Bool = false) -> URL? {
        script(host, port, "Programmer/Editor/ClearSelection", [("disable", "false"), ("clearAllProgrammers", everyUser ? "true" : "false")])
    }

    /// Empties that WebAPI user's own selection.
    static func clearSelectionURL(host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Selection/Context/Global/Clear", [])
    }

    /// Selects fixtures by user number in that WebAPI user's own selection.
    static func selectFixturesURL(userNumbers: [Int], host: String, port: Int = defaultPort) -> URL? {
        guard !userNumbers.isEmpty else { return nil }
        return script(host, port, "Selection/Context/Global/SelectFixturesFromHandles",
                      [("handleList_userNumberList", userNumbers.map(String.init).joined(separator: ","))])
    }

    /// Patch route to a fixture's DMX address: copy the selected fixture's
    /// address into the patch editor's properties, then read them. Only ever
    /// sent to the separate WebAPI user (4430), never the operator's UI.
    static func addressFromSelectionURL(host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Patch/Repatch/SetDmxAddressesFromSelectedFixture", [])
    }

    static func currentDmxAssignmentURL(host: String, port: Int = defaultPort) -> URL? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else { return nil }
        return URL(string: "http://\(authority(host, port))/titan/get/2/Patch/CurrentDmxAssignment")
    }

    /// Releases the selection's edited controls from the programmer, over a time.
    static func releaseSelectionURL(seconds: Double, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Programmer/Editor/Fixtures/ClearSelectedControls", [
            ("release", "true"), ("releaseTime", format(number: max(seconds, 0))),
        ])
    }

    /// GET /titan/get/System/SoftwareVersion - a cheap "are you there" check.
    static func softwareVersionURL(host: String, port: Int = defaultPort) -> URL? {
        URL(string: "http://\(authority(host, port))/titan/get/System/SoftwareVersion")
    }

    // MARK: Command line (keypad Enter / Clear)

    /// GET the text currently on Titan's command line.
    static func commandLineTextURL(host: String, port: Int = defaultPort) -> URL? {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: "http://\(authority(host, port))/titan/get/2/Command/CommandLineText")
    }

    static func runCommandURL(_ command: String, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Command/RunCommand", [("command", command)])
    }

    static func startNewCommandURL(host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Command/StartNewCommand", [])
    }

    /// Clears the programmer (this one only) and the selection.
    /// `allProgrammers`: every user's programmer, the desk's own included (Titan
    /// 19's WebAPI is a separate user), as the console's Clear all programmers.
    static func clearProgrammerURL(host: String, port: Int = defaultPort, allProgrammers: Bool = false) -> URL? {
        // Programmer.Editor: Titan 19.2 only answers the old Playbacks.Editor name
        // with pre19Compatibility on; the Programmer one is in both.
        script(host, port, "Programmer/Editor/ClearAll", [("presets", "false"), ("allProgrammers", allProgrammers ? "true" : "false")])
    }

    /// Any number, without trailing zeros ("5", "-2.5").
    static func format(number: Double) -> String {
        if number == number.rounded() { return String(Int(number)) }
        var text = String(format: "%.3f", number)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    /// GET /titan/handles/<group> - every handle in a group, with its Active flag.
    static func handlesURL(group: String, host: String, port: Int = defaultPort) -> URL? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = cleanHost
        components.port = port
        components.path = "/titan/handles/" + group
        return components.url
    }

    /// Levels are clamped to 0-1 and sent without trailing zeros ("0.5", "1").
    static func format(level: Double) -> String {
        let clamped = min(max(level, 0), 1)
        if clamped == clamped.rounded() { return String(Int(clamped)) }
        var text = String(format: "%.3f", clamped)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }

    private static func authority(_ host: String, _ port: Int) -> String {
        "\(host.trimmingCharacters(in: .whitespacesAndNewlines)):\(port)"
    }

    private static func script(_ host: String, _ port: Int, _ function: String, _ params: [(String, String)]) -> URL? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = cleanHost
        components.port = port
        components.path = scriptRoot + function
        // Encode by hand: Foundation versions disagree on escaping & = + in values.
        components.percentEncodedQuery = params.isEmpty ? nil : params
            .map { "\(encode($0.0))=\(encode($0.1))" }
            .joined(separator: "&")
        return components.url
    }

    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }
}

/// Titan 19's cue times are an AcwTimeSpan in JSON: a bare number is refused
/// ("The JSON value could not be converted to Avolites.Acw.Titan.AcwTimeSpan"),
/// and the API docs don't show its shape. So a time is written in the shape
/// Titan itself gives when the same property is read, and failing that, in the
/// likely shapes one after another. Pure, so it's tested. (In this file
/// because the Watch target compiles a fixed list of files.)
enum TitanTimeSpan {
    /// Bodies to try in turn, best first: Titan's own shape (Titan 19 reads a
    /// cue time as {"TimeType":0,"TimeValue":"00:00:00","TotalSeconds":0,
    /// "TimeOrDefault":"00:00:00","HasValue":true}) with the time written
    /// short ("00:00:02.5") and then as .NET does ("00:00:02.5000000"), then
    /// those as plain strings, then a number.
    static func bodies(seconds: Double, current: Data?) -> [Data] {
        var bodies: [Data] = []
        if let current {
            if let shaped = shaped(seconds: seconds, like: current, text: shortTimeText) { bodies.append(shaped) }
            if let shaped = shaped(seconds: seconds, like: current) { bodies.append(shaped) }
        }
        bodies.append(Data("\"\(shortTimeText(seconds))\"".utf8))
        bodies.append(Data("\"\(timeSpanText(seconds))\"".utf8))                         // .NET TimeSpan
        bodies.append(Data(TitanEndpoints.format(number: seconds).utf8))                  // older Titans
        // Never a guessed object like {"Seconds": n}: Titan ignores names it
        // doesn't know and could take it as 0 s without saying so.
        var seen = Set<Data>()
        return bodies.filter { seen.insert($0).inserted }
    }

    /// The seconds in one of Titan's answers about a time (a number, a
    /// TimeSpan string, or an object with a time in it), or nil.
    static func seconds(from data: Data) -> Double? {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return seconds(in: .string(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)),
                           key: nil)
        }
        return seconds(in: value, key: nil)
    }

    private static func seconds(in value: JSONValue, key: String?) -> Double? {
        let name = key?.lowercased() ?? ""
        switch value {
        case .number(let number):
            if name.contains("type") { return nil }   // TimeType is a kind of time, not a time
            if name.contains("tick") { return number / 10_000_000 }
            if name.contains("milli") { return number / 1000 }
            if key == nil || name.contains("second") || name.contains("time") || name.contains("duration") || name == "value" {
                return number
            }
            return nil
        case .string(let text):
            if let number = Double(text) { return number }
            guard isTimeSpan(text) else { return nil }
            let parts = text.split(separator: ":")
            guard parts.count == 3, let h = Double(parts[0].split(separator: ".").last ?? ""),
                  let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
            let days = parts[0].contains(".") ? Double(parts[0].split(separator: ".").first ?? "") ?? 0 : 0
            return days * 86400 + h * 3600 + m * 60 + s
        case .object(let fields):
            for (field, inner) in fields.sorted(by: { $0.key < $1.key }) {
                if let found = seconds(in: inner, key: field) { return found }
            }
            return nil
        case .bool, .array, .null:
            return nil
        }
    }

    /// "00:00:02.5": hours, minutes, seconds and only the fraction there is,
    /// like Titan's own "00:00:00".
    static func shortTimeText(_ seconds: Double) -> String {
        let full = timeSpanText(seconds)
        guard full.contains(".") else { return full }
        var trimmed = full
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        return trimmed.hasSuffix(".") ? String(trimmed.dropLast()) : trimmed
    }

    /// "00:00:02.5000000", as .NET writes a TimeSpan.
    static func timeSpanText(_ seconds: Double) -> String {
        let ticks = Int64((max(seconds, 0) * 10_000_000).rounded())
        let total = ticks / 10_000_000
        let fraction = ticks % 10_000_000
        let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
        let base = String(format: "%02lld:%02lld:%02lld", h, m, s)
        return fraction == 0 ? base : base + String(format: ".%07lld", fraction)
    }

    /// `seconds` written like `current`: the same JSON with its time fields
    /// replaced (times as `text` writes them), its kind and flags left alone.
    static func shaped(seconds: Double, like current: Data, text: (Double) -> String = timeSpanText) -> Data? {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: current),
              let replaced = replace(value, seconds: seconds, key: nil, text: text) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(replaced)
    }

    /// The value with every time in it set to `seconds`, or nil if there's none.
    private static func replace(_ value: JSONValue, seconds: Double, key: String?,
                                text write: (Double) -> String) -> JSONValue? {
        let name = key?.lowercased() ?? ""
        switch value {
        case .string(let text):
            if isTimeSpan(text) { return .string(write(seconds)) }
            if Double(text) != nil { return .string(TitanEndpoints.format(number: seconds)) }
            return nil
        case .number:
            if name.contains("type") { return nil }   // TimeType: which kind of time, never the time
            if name.contains("tick") { return .number((seconds * 10_000_000).rounded()) }
            if name.contains("milli") { return .number(seconds * 1000) }
            if key == nil || name.contains("second") || name.contains("time") || name.contains("duration") || name == "value" {
                return .number(seconds)
            }
            return nil
        case .object(let fields):
            var changed = false
            var out = fields
            for (field, inner) in fields {
                if let new = replace(inner, seconds: seconds, key: field, text: write) {
                    out[field] = new
                    changed = true
                }
            }
            return changed ? .object(out) : nil
        case .bool, .array, .null:
            return nil
        }
    }

    private static func isTimeSpan(_ text: String) -> Bool {
        text.range(of: #"^-?(\d+\.)?\d{1,2}:\d{2}:\d{2}(\.\d+)?$"#, options: .regularExpression) != nil
    }
}

/// Any JSON, for copying the shape of one of Titan's answers.
indirect enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let bool = try? container.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? container.decode(Double.self) { self = .number(number) }
        else if let string = try? container.decode(String.self) { self = .string(string) }
        else if let array = try? container.decode([JSONValue].self) { self = .array(array) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value):
            if value == value.rounded(), abs(value) < 1e15 { try container.encode(Int64(value)) } else { try container.encode(value) }
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
