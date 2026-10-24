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
            // Assumes IncrementDimmer takes percent, like SetDimmerLevel does - check on the console.
            return script(host, port, "Programmer/Editor/Fixtures/IncrementDimmer", [
                ("value", format(number: percent)),
                ("timeDelta", "1"),
                ("shiftEnabled", "false"),
            ])
        case .recallWorkspace(let n):
            return script(host, port, "Workspace/Apply", [("handle_userNumber", "\(n)")])
        case .keypadEnter, .keypadClear, .colourTemperature:
            return nil   // several requests - TitanClient runs them
        case .switchPage, .openSettings, .nextPage, .previousPage, .mainMenu, .colourPresets:
            return nil
        }
    }

    /// Palette/ApplyPalette on the selection, without the palette's own times.
    static func applyPaletteURL(titanId: Int, host: String, port: Int = defaultPort) -> URL? {
        script(host, port, "Palette/ApplyPalette", [("handle_titanId", "\(titanId)"), ("usePaletteTimes", "false")])
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
        script(host, port, "Playbacks/Editor/ClearAll", [("presets", "false"), ("allProgrammers", "false")])
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
