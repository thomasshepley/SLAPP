// App/StartupChecks.swift
import Foundation

/// What the loading screen checks before Continue: Titan, the Stream Deck,
/// the PC's remote desktop, TitanDeck Host, sACN levels and the desk link.
/// Each runs at once with a short timeout; nothing here changes anything.
@MainActor
final class StartupChecks: ObservableObject {
    enum State: Equatable {
        case checking, ok, warning, off
    }

    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let symbol: String
        var state: State = .checking
        var detail = "Checking..."
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var running = false

    var isDone: Bool { !running && !rows.contains { $0.state == .checking } }
    var warnings: Int { rows.filter { $0.state == .warning }.count }

    private var run: Task<Void, Never>?
    /// In Show mode a test tool answering (Fake Titan, a Host in Test mode) is worth a warning.
    private var showMode = false

    func start(_ app: AppState, remoteDesktop: Bool, showMode: Bool) {
        self.showMode = showMode
        run?.cancel()
        rows = [
            Row(id: "titan", title: "Titan", symbol: "slider.horizontal.3"),
            Row(id: "deck", title: "Stream Deck", symbol: "square.grid.3x3.fill"),
            Row(id: "rdp", title: "Remote desktop", symbol: "display"),
            Row(id: "host", title: "TitanDeck Host", symbol: "desktopcomputer"),
            Row(id: "sacn", title: "Live levels (sACN)", symbol: "light.max"),
            Row(id: "desk", title: "Desk link", symbol: "scope"),
        ]
        running = true
        run = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self?.checkTitan(app) }
                group.addTask { await self?.checkDeck(app) }
                group.addTask { await self?.checkRemote(app, enabled: remoteDesktop) }
                group.addTask { await self?.checkHost(app) }
                group.addTask { await self?.checkDesk(app) }
            }
            self?.running = false
        }
    }

    private func set(_ id: String, _ state: State, _ detail: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].state = state
        rows[index].detail = detail
    }

    private func checkTitan(_ app: AppState) async {
        let host = app.titanHost.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else {
            return set("titan", .warning, "No Titan PC address yet: Settings > Titan.")
        }
        // A few tries: Wi-Fi can take a moment to come up after unlocking.
        for attempt in 0 ..< 4 {
            if let version = await app.titan.softwareVersion() {
                if showMode && version.localizedCaseInsensitiveContains("Fake Titan") {
                    return set("titan", .warning, "That's Fake Titan at \(host), not the desk. Stop it in TitanDeck Host and start Titan.")
                }
                return set("titan", .ok, "Titan \(version) at \(host)")
            }
            if attempt < 3 { try? await Task.sleep(nanoseconds: 500_000_000) }
        }
        set("titan", .warning, "Titan isn't answering at \(host). Is Titan running, with its WebAPI on?")
    }

    private func checkDeck(_ app: AppState) async {
        // Give a deck that's just been plugged in a moment to show up.
        for _ in 0 ..< 6 where app.deck.device == nil {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        if let device = app.deck.device {
            set("deck", .ok, "\(device.info.productName) attached")
        } else {
            set("deck", .warning, "No Stream Deck found. Plug it in, or use the Deck tab on screen.")
        }
    }

    private func checkRemote(_ app: AppState, enabled: Bool) async {
        guard enabled else { return set("rdp", .off, "Off in Settings") }
        let host = app.pcHost
        guard !host.isEmpty else { return set("rdp", .warning, "No PC address yet.") }
        if await TCPProbe.canConnect(host: host, port: 3389, timeout: 2.5) {
            set("rdp", .ok, "The PC's remote desktop is answering (\(host))")
        } else {
            set("rdp", .warning, "The PC's remote desktop (port 3389) isn't answering at \(host).")
        }
    }

    private func checkHost(_ app: AppState) async {
        guard app.host.isPaired else {
            set("host", .off, "Not paired (optional: Settings > TitanDeck Host)")
            return set("sacn", .off, "Needs TitanDeck Host")
        }
        await app.host.refresh(full: true)
        guard case .online(let hello) = app.host.connection else {
            set("host", .warning, "\(app.host.displayName) isn't answering. Is the PC on and the Host running?")
            return set("sacn", .off, "Needs TitanDeck Host")
        }
        let rdp = app.host.status.map { $0.overall == .ok ? ", remote desktop set up" : ", remote desktop needs a look" } ?? ""
        if showMode && app.host.status?.mode == "test" {
            set("host", .warning, "\(hello.machineName), Host \(hello.hostVersion), still in Test mode: switch it to Show in the Host window.")
        } else {
            set("host", .ok, "\(hello.machineName), Host \(hello.hostVersion)\(rdp)")
        }

        guard app.intensity.isEnabled, let client = app.host.client else {
            return set("sacn", .off, "Live intensity is off in Settings")
        }
        if let summary = try? await client.dmxSummary() {
            if let problem = summary.problem {
                set("sacn", .warning, problem)
            } else if summary.universes.isEmpty {
                set("sacn", .warning, "No sACN from Titan yet (fine if nothing's patched or Titan isn't running).")
            } else {
                set("sacn", .ok, "Hearing universe\(summary.universes.count == 1 ? "" : "s") "
                    + summary.universes.prefix(8).map(String.init).joined(separator: ", "))
            }
        } else {
            set("sacn", .warning, "The Host didn't answer about sACN.")
        }
    }

    private func checkDesk(_ app: AppState) async {
        guard app.deskLink.isEnabled else { return set("desk", .off, "Off in Settings") }
        for _ in 0 ..< 10 {
            if app.deskLink.state == .linked { break }
            if case .unavailable = app.deskLink.state { break }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        switch app.deskLink.state {
        case .linked: set("desk", .ok, "Following the desk's selection")
        case .unavailable(let reason): set("desk", .warning, reason)
        case .connecting: set("desk", .warning, "Still looking for the desk's UI WebAPI.")
        case .off: set("desk", .off, "Off")
        }
    }
}
