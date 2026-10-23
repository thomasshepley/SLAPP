// App/TitanIntents.swift
import AppIntents
import Foundation

/// Shortcuts / Siri / Action button / Control Center actions. They talk to
/// Titan directly using the saved host, so they work without opening the app.

enum PlaybackCommand: String, AppEnum {
    case go
    case release

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Playback command"
    static var caseDisplayRepresentations: [PlaybackCommand: DisplayRepresentation] = [
        .go: "Go",
        .release: "Release",
    ]

    func action(userNumber: Int) -> TitanAction {
        switch self {
        case .go: return .playbackGo(userNumber: userNumber)
        case .release: return .playbackRelease(userNumber: userNumber)
        }
    }
}

enum TitanIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noHost
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noHost: return "Set the Titan PC address in TitanDeck's Settings first."
        case .failed(let reason): return "Titan didn't respond: \(reason)"
        }
    }
}

struct FirePlaybackIntent: AppIntent {
    static var title: LocalizedStringResource = "Fire Titan Playback"
    static var description = IntentDescription("Fires or releases a Titan playback by its user number.")

    @Parameter(title: "Playback", inclusiveRange: (1, 9999))
    var playback: Int

    @Parameter(title: "Command", default: .go)
    var command: PlaybackCommand

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$command) playback \(\.$playback)")
    }

    init() {}

    init(playback: Int, command: PlaybackCommand) {
        self.playback = playback
        self.command = command
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let host = UserDefaults.standard.string(forKey: SettingsKeys.titanHost) ?? ""
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else { throw TitanIntentError.noHost }
        // A little more patience than a deck key: this may be the first packet after waking.
        let result = await TitanClient(host: host, timeout: 2).perform(command.action(userNumber: playback))
        guard result.ok else {
            throw TitanIntentError.failed(result.error ?? "HTTP \(result.statusCode ?? 0)")
        }
        let verb = command == .go ? "fired" : "released"
        return .result(dialog: "Playback \(playback) \(verb) (\(result.milliseconds) ms).")
    }
}

struct RunMacroIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Titan Macro"
    static var description = IntentDescription("Runs a Titan macro by its macro id.")

    @Parameter(title: "Macro id")
    var macroId: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let host = UserDefaults.standard.string(forKey: SettingsKeys.titanHost) ?? ""
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else { throw TitanIntentError.noHost }
        let result = await TitanClient(host: host, timeout: 2).perform(.runMacro(id: macroId))
        guard result.ok else {
            throw TitanIntentError.failed(result.error ?? "HTTP \(result.statusCode ?? 0)")
        }
        return .result(dialog: "Macro \(macroId) run.")
    }
}

struct TitanDeckShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FirePlaybackIntent(),
            phrases: [
                "Fire a playback in \(.applicationName)",
                "Titan go with \(.applicationName)",
            ],
            shortTitle: "Fire Playback",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: RunMacroIntent(),
            phrases: ["Run a Titan macro in \(.applicationName)"],
            shortTitle: "Run Macro",
            systemImageName: "wand.and.stars"
        )
    }
}
