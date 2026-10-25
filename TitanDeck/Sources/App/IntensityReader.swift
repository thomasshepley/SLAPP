// App/IntensityReader.swift
import Foundation

/// The selected fixture's live level, for the deck's flash key. Titan's
/// WebAPI can't report a level, so it's read from the sACN Titan sends,
/// through TitanDeck Host. Which channels are the fixture's intensity is
/// learned the first time the deck nudges or flashes it (the channels that
/// move with it), and remembered. Optionally (both off by default) Titan's
/// patch report, read by the Host, gives the intensity channels straight
/// away, and the Patch route finds the fixture's address to narrow the
/// search. What's learnt from a nudge always wins over the report.
@MainActor
final class IntensityReader: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            refresh()
        }
    }
    /// Use the patch from Titan's patch report (TitanDeck Host 0.6+): the
    /// level shows without a nudge first. Reading a report never touches Patch.
    @Published var usesPatchReport: Bool {
        didSet {
            defaults.set(usesPatchReport, forKey: Keys.patchReport)
            patch = [:]
            patchRead = nil
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
        static let patchReport = "intensity.patchReport"
        static let learned = "intensity.learned"
    }

    private let defaults: UserDefaults
    private let api: TitanClient
    private let host: @MainActor () -> HostClient?
    private let deskLinked: @MainActor () -> Bool
    private var fixture: Int?
    private var addresses: [Int: DmxAddress] = [:]
    private var lookedUp: Set<Int> = []
    /// The patch report by user number, and when it was fetched.
    private var patch: [Int: HostPatchFixture] = [:]
    private var patchRead: Date?
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
        usesPatchReport = defaults.object(forKey: Keys.patchReport) as? Bool ?? false
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
        let fromReport = patch[fixture]
        let near = addresses[fixture] ?? fromReport.map { DmxAddress(universe: $0.universe, address: $0.address) }
        guard let slots = IntensityLearning.channels(before: before, after: after, rising: rising,
                                                     near: near, span: fromReport?.channels ?? 64) else {
            if learned[fixture] == nil {
                note = "Couldn't tell which channels are fixture \(fixture)'s intensity yet - nudge it once more."
            }
            return
        }
        learned[fixture] = slots
        save()
        var text = "Fixture \(fixture): intensity on " + Self.describe(slots)
        if let fromReport, let reported = IntensityLearning.slots(for: fromReport), reported != slots {
            // Titan's DMX line numbers needn't be its sACN universe numbers.
            text += " (the patch report said \(Self.describe(reported)): check which sACN universe line \(fromReport.universe) goes out on)"
        }
        note = text
        refresh()
    }

    private func refresh() {
        poll?.cancel()
        poll = nil
        recent = nil
        setLevel(nil)
        guard isEnabled, let fixture else { return }
        poll = Task { [weak self] in
            await self?.loadPatch()
            await self?.lookUpAddress(fixture)
            while !Task.isCancelled {
                guard let self else { return }
                if self.slots(for: fixture) == nil {
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

    /// Learnt from a nudge, else from the patch report.
    private func slots(for fixture: Int) -> [DmxSlot]? {
        learned[fixture] ?? patch[fixture].flatMap(IntensityLearning.slots(for:))
    }

    /// The patch report, fetched again when it's more than 30 s old.
    private func loadPatch() async {
        guard usesPatchReport, let host = host() else { return }
        if let patchRead, Date().timeIntervalSince(patchRead) < 30 { return }
        patchRead = Date()
        guard let report = try? await host.patch() else {
            note = "TitanDeck Host didn't send a patch (it needs Host 0.6 or later)."
            return
        }
        patch = Dictionary(report.fixtures.map { ($0.user, $0) }, uniquingKeysWith: { first, _ in first })
        guard let fixture, learned[fixture] == nil else { return }
        if let entry = patch[fixture] {
            note = IntensityLearning.slots(for: entry).map {
                "Fixture \(fixture): intensity on \(Self.describe($0)), from the patch report (\(report.source ?? "Titan"))."
            } ?? "Fixture \(fixture) is in the patch report at \(entry.universe).\(entry.address), but the Host couldn't find its personality - nudge it once."
        } else {
            note = report.fixtures.isEmpty
                ? (report.problem ?? "The Host has no patch report yet.")
                : "Fixture \(fixture) isn't in the patch report - make a new one after repatching."
        }
    }

    private static func describe(_ slots: [DmxSlot]) -> String {
        slots.map { "\($0.universe).\($0.address)" }.joined(separator: ", ")
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
        await loadPatch()
        guard let slots = slots(for: fixture), let host = host() else {
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
