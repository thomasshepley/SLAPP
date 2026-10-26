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
        case .keypadExit:
            return script(host, port, "Menu/ExitRootOrLatched", [])
        case .adjustIntensity(let percent):
            // Wheel steps (see dimmerStepsPerPercent); timeDelta 1 s = turned slowly, so no acceleration.
            return script(host, port, "Programmer/Editor/Fixtures/IncrementDimmer", [
                ("value", format(number: percent * dimmerStepsPerPercent)),
                ("timeDelta", "1"),
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
    static func clearProgrammerURL(host: String, port: Int = defaultPort) -> URL? {
        // Programmer.Editor: Titan 19.2 only answers the old Playbacks.Editor name
        // with pre19Compatibility on; the Programmer one is in both.
        script(host, port, "Programmer/Editor/ClearAll", [("presets", "false"), ("allProgrammers", "false")])
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
