// App/IntensityReader.swift
import Foundation

/// The selected fixture's live level, for the deck's flash key. Titan's
/// WebAPI can't report a level, so it's read from the sACN Titan sends,
/// through TitanDeck Host. Which channels are the fixture's intensity is
/// learned the first time the deck nudges or flashes it (the channels that
/// move with it), and remembered. Optionally, the Patch route finds the
/// fixture's address first, which narrows the search - off by default.
@MainActor
final class IntensityReader: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            refresh()
        }
    }
    /// Experimental: look the fixture's address up through Titan's patch
    /// editor (Patch/Repatch), on the separate WebAPI user only.
    @Published var usesPatchLookup: Bool {
        didSet { defaults.set(usesPatchLookup, forKey: Keys.patch) }
    }
    /// 0...1, or nil when it isn't known.
    @Published private(set) var level: Double?
    @Published private(set) var learned: [Int: [DmxSlot]]
    @Published private(set) var note: String?

    var onLevel: ((Double?) -> Void)?

    private enum Keys {
        static let enabled = "intensity.live.enabled"
        static let patch = "intensity.patchLookup"
        static let learned = "intensity.learned"
    }

    private let defaults: UserDefaults
    private let api: TitanClient
    private let host: @MainActor () -> HostClient?
    private let deskLinked: @MainActor () -> Bool
    private var fixture: Int?
    private var addresses: [Int: DmxAddress] = [:]
    private var lookedUp: Set<Int> = []
    private var poll: Task<Void, Never>?
    private var learning: Task<Void, Never>?
    /// Until a fixture is learnt: the whole of every universe, kept fresh,
    /// so a press has a "before" without waiting for one.
    private var recent: (taken: Date, levels: IntensityLearning.Snapshot)?

    /// `api` is the normal WebAPI (4430): the only one the Patch route ever uses.
    init(api: TitanClient, host: @escaping @MainActor () -> HostClient?, deskLinked: @escaping @MainActor () -> Bool,
         defaults: UserDefaults = .standard) {
        self.api = api
        self.host = host
        self.deskLinked = deskLinked
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        usesPatchLookup = defaults.object(forKey: Keys.patch) as? Bool ?? false
        learned = (defaults.data(forKey: Keys.learned)).flatMap {
            try? JSONDecoder().decode([Int: [DmxSlot]].self, from: $0)
        } ?? [:]
    }

    /// The fixture the deck is showing intensity keys for, or nil.
    func setFixture(_ newFixture: Int?) {
        guard newFixture != fixture else { return }
        fixture = newFixture
        refresh()
    }

    func forgetLearned() {
        learned = [:]
        addresses = [:]
        lookedUp = []
        defaults.removeObject(forKey: Keys.learned)
        refresh()
    }

    /// Call just before the deck sends an action. If it moves the selected
    /// fixture's level, the channels that move with it are learned.
    func deckWillSend(_ action: TitanAction) {
        guard isEnabled, let fixture, let rising = IntensityLearning.direction(of: action), learning == nil,
              let host = host() else { return }
        // "Before" has to be from before the press, so it's the latest kept
        // snapshot; taking one now would race the action on its way to Titan.
        guard let recent, Date().timeIntervalSince(recent.taken) < 1.5 else { return }
        let before = recent.levels
        learning = Task { [weak self] in
            await self?.learn(fixture: fixture, rising: rising, before: before, host: host)
            self?.learning = nil
        }
    }

    private func learn(fixture: Int, rising: Bool, before: IntensityLearning.Snapshot, host: HostClient) async {
        try? await Task.sleep(nanoseconds: 700_000_000)   // Titan, then sACN, catch up
        guard let after = await snapshot(host), self.fixture == fixture else { return }
        guard let slots = IntensityLearning.channels(before: before, after: after, rising: rising,
                                                     near: addresses[fixture]) else {
            if learned[fixture] == nil {
                note = "Couldn't tell which channels are fixture \(fixture)'s intensity yet - nudge it once more."
            }
            return
        }
        learned[fixture] = slots
        save()
        note = "Fixture \(fixture): intensity on " + slots.map { "\($0.universe).\($0.address)" }.joined(separator: ", ")
        refresh()
    }

    private func refresh() {
        poll?.cancel()
        poll = nil
        recent = nil
        setLevel(nil)
        guard isEnabled, let fixture else { return }
        poll = Task { [weak self] in
            await self?.lookUpAddress(fixture)
            while !Task.isCancelled {
                guard let self else { return }
                if self.learned[fixture] == nil {
                    // Not learnt yet: keep a fresh "before" for the next nudge.
                    if let host = self.host(), let levels = await self.snapshot(host) {
                        self.recent = (Date(), levels)
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                } else {
                    await self.read(fixture)
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }
    }

    private func lookUpAddress(_ fixture: Int) async {
        guard usesPatchLookup, addresses[fixture] == nil, !lookedUp.contains(fixture) else { return }
        lookedUp.insert(fixture)
        // Linked to the desk, the 4430 user's own selection is free to use for
        // this; otherwise it already holds what the deck selected.
        let (address, raw) = await api.patchedAddress(selecting: deskLinked() ? fixture : nil)
        if let address {
            addresses[fixture] = address
        } else if let raw {
            note = "Titan's patch answered \"\(raw.prefix(80))\" - TitanDeck can't read that yet."
        }
    }

    private func read(_ fixture: Int) async {
        guard let slots = learned[fixture], let host = host() else {
            setLevel(nil)
            return
        }
        var snapshot: IntensityLearning.Snapshot = [:]
        for (universe, inUniverse) in Dictionary(grouping: slots, by: \.universe) {
            let first = inUniverse.map(\.address).min() ?? 1
            let last = inUniverse.map(\.address).max() ?? first
            guard let answer = try? await host.dmx(universe: universe, start: first, count: last - first + 1) else {
                setLevel(nil)
                return
            }
            var levels = [Int](repeating: 0, count: 512)
            for (offset, value) in answer.levels.enumerated() where answer.start - 1 + offset < 512 {
                levels[answer.start - 1 + offset] = value
            }
            snapshot[universe] = levels
        }
        guard self.fixture == fixture else { return }
        setLevel(IntensityLearning.level(of: slots, in: snapshot))
    }

    /// Every universe the Host hears, in full.
    private func snapshot(_ host: HostClient) async -> IntensityLearning.Snapshot? {
        guard let summary = try? await host.dmxSummary(), !summary.universes.isEmpty else {
            note = "TitanDeck Host doesn't hear any sACN from Titan yet."
            return nil
        }
        var snapshot: IntensityLearning.Snapshot = [:]
        for universe in summary.universes.prefix(32) {
            if let answer = try? await host.dmx(universe: universe) { snapshot[universe] = answer.levels }
        }
        return snapshot.isEmpty ? nil : snapshot
    }

    private func setLevel(_ newLevel: Double?) {
        guard newLevel != level else { return }
        level = newLevel
        onLevel?(newLevel)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(learned), forKey: Keys.learned)
    }
}
