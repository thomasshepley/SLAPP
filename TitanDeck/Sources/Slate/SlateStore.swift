// Slate/SlateStore.swift
import Foundation

/// The Slate Book, kept by TitanDeck Host (0.13+) from Titan's sACN: the
/// slate showing, the day's lines, and the deck's and app's buttons for it.
@MainActor
final class SlateStore: ObservableObject {
    /// What the deck's Slate page and the app ask the Host to do.
    enum Command: Equatable {
        case take
        case newSlate(String?)
        case letter
        case toggleNight
        case toggleFx
    }

    @Published private(set) var state: HostSlateState?
    @Published private(set) var book: HostSlateBook?
    /// The day being looked at; nil is today.
    @Published var day: String? {
        didSet { if day != oldValue { Task { await refresh() } } }
    }
    @Published private(set) var problem: String?
    @Published private(set) var busy = false

    /// Called after a command, ok or not, so the deck can flash the key.
    var onResult: ((Bool) -> Void)?
    /// Called when the slate showing changes, for the deck's slate keys.
    var onState: ((HostSlateState?) -> Void)?

    private let client: () -> HostClient?

    init(client: @escaping () -> HostClient?) {
        self.client = client
    }

    var isViewingToday: Bool { day == nil }

    /// The whole day's book (the Slates tab while it's open).
    func refresh() async {
        guard let client = client() else {
            problem = "Pair with TitanDeck Host (0.13 or later) to keep a Slate Book."
            return
        }
        do {
            let answer: HostSlateBook
            if let day {
                answer = try await client.slateBook(day: day)
            } else {
                answer = try await client.slateBook()
            }
            book = answer
            if day == nil { show(answer.state) }
            problem = answer.problem ?? (answer.listening ? nil : "No sACN from Titan reaching the Host, so nothing can be logged.")
        } catch {
            problem = Self.message(error)
        }
    }

    /// Just the slate showing, for the deck (cheap enough to poll).
    func refreshState() async {
        guard let client = client(), let answer = try? await client.slateBook(summary: true) else { return }
        show(answer.state)
    }

    func keepRefreshing(every interval: Duration = .seconds(3)) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }

    func keepStateFresh(every interval: Duration = .seconds(5)) async {
        while !Task.isCancelled {
            await refreshState()
            try? await Task.sleep(for: interval)
        }
    }

    func run(_ command: Command) {
        Task { await perform(command) }
    }

    @discardableResult
    func perform(_ command: Command) async -> Bool {
        guard let client = client() else {
            problem = "Pair with TitanDeck Host to keep a Slate Book."
            onResult?(false)
            return false
        }
        busy = true
        defer { busy = false }
        do {
            switch command {
            case .take: _ = try await client.slateTake()
            case .newSlate(let slate): _ = try await client.slateNew(slate)
            case .letter: _ = try await client.slateLetter()
            case .toggleNight: _ = try await client.slateSet(HostSlateSetRequest(night: !(state?.night ?? false)))
            case .toggleFx: _ = try await client.slateSet(HostSlateSetRequest(fx: !(state?.fx ?? false)))
            }
            problem = nil
            day = nil
            await refresh()
            onResult?(true)
            return true
        } catch {
            problem = Self.message(error)
            onResult?(false)
            return false
        }
    }

    /// Puts the slate or take right by hand (no look logged).
    func correct(slate: String?, take: Int?) async {
        guard let client = client() else { return }
        do {
            _ = try await client.slateSet(HostSlateSetRequest(slate: slate, take: take))
            await refresh()
        } catch {
            problem = Self.message(error)
        }
    }

    func note(_ entry: HostSlateEntry, _ text: String) async {
        guard let client = client(), let shownDay = book?.day else { return }
        do {
            _ = try await client.slateNote(day: shownDay, id: entry.id, note: text)
            await refresh()
        } catch {
            problem = Self.message(error)
        }
    }

    func match(_ entry: HostSlateEntry) async -> Result<HostSlateMatch, Error> {
        guard let client = client(), let shownDay = book?.day else { return .failure(HostError.noAddress) }
        do {
            return .success(try await client.slateMatch(day: shownDay, id: entry.id))
        } catch {
            return .failure(error)
        }
    }

    private func show(_ newState: HostSlateState) {
        guard newState != state else { return }
        state = newState
        onState?(newState)
    }

    static func message(_ error: Error) -> String {
        if case HostError.server(404, _) = error { return "This TitanDeck Host doesn't keep a Slate Book yet: update it to 0.13 or later." }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
