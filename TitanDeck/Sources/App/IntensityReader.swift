// App/IntensityReader.swift
import Foundation

/// The selected fixture's live level, for the deck's flash key. Titan's
/// WebAPI can't report a level, and its CITP link brings the patch and
/// the selection (a visualiser gets live levels from Titan by sACN or
/// Art-Net), so it's read from the sACN Titan sends, through TitanDeck
/// Host. Titan's patch (over CITP, or a patch report) says which
/// channels are the fixture's intensity. Only for a fixture the patch
/// doesn't know are they learned the first time the deck nudges or flashes
/// it (the channels that move with it), and remembered. Until 0.45.2 what
/// was learnt won over the patch, so channels learnt on an old show kept
/// being read on the next one. The reading is checked against what the
/// deck sets (`deckSet`): one that doesn't follow isn't shown or used.
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
    /// Why there's no live level for the selected fixture, in a line for the
    /// deck's selection card (0.45.2); nil when there is one, or nothing's selected.
    @Published private(set) var whyNotLive: String?

    var onLevel: ((Double?) -> Void)?

    private enum Keys {
        static let enabled = "intensity.live.enabled"
        static let patch = "intensity.patchLookup"
        /// v2: on by default, now Titan's patch also comes over CITP (Host 0.12).
        static let patchReport = "intensity.patch.v2"
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
    /// What the Host said was wrong with its patch, if anything.
    private var patchProblem: String?
    private var poll: Task<Void, Never>?
    private var learning: Task<Void, Never>?
    /// The latest reading, shown or not.
    private var raw: Double?
    /// Fixtures whose reading didn't follow a level the deck set, and why.
    /// Until one does, the deck goes by what it set itself.
    private var distrusted: [Int: String] = [:]
    private var followCheck: Task<Void, Never>?
    /// Reads in a row the Host didn't answer.
    private var misses = 0
    /// Long enough for the line to be typed on the desk, Titan to output it
    /// and the Host to hear it.
    static let followDelay: Duration = .seconds(3)
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
        usesPatchReport = defaults.object(forKey: Keys.patchReport) as? Bool ?? true
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
        distrusted = [:]
        defaults.removeObject(forKey: Keys.learned)
        refresh()
    }

    /// The deck has just set the selection to this level (0...1), at once
    /// (not a fade). A few seconds on, the reading should be there; if it
    /// isn't, it isn't this fixture's level as the deck sets it, so it's not
    /// shown or used for the next nudge until one does follow.
    func deckSet(level expected: Double) {
        followCheck?.cancel()
        guard isEnabled, let fixture else { return }
        followCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.followDelay)
            guard !Task.isCancelled, let self, self.fixture == fixture, let read = self.raw else { return }
            if IntensityLearning.follows(set: expected, read: read) {
                guard self.distrusted.removeValue(forKey: fixture) != nil else { return }
                self.whyNotLive = nil
                self.setLevel(read)
            } else {
                let why = "Fixture \(fixture) reads \(Self.percent(read)) on sACN after the deck set \(Self.percent(expected)), so the reading isn't shown: a master below full, a fade time, or not its intensity channel."
                self.distrusted[fixture] = why
                self.whyNotLive = why
                self.note = why
                self.setLevel(nil)
            }
        }
    }

    /// The level the deck was about to check for didn't go out (the key
    /// failed), or is about to change on purpose (a flash, a fade).
    func cancelFollowCheck() {
        followCheck?.cancel()
        followCheck = nil
    }

    private static func percent(_ level: Double) -> String {
        "\(Int((min(max(level, 0), 1) * 100).rounded()))%"
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
        raw = nil
        misses = 0
        followCheck?.cancel()
        followCheck = nil
        setLevel(nil)
        whyNotLive = nil
        guard let fixture else { return }
        guard isEnabled else {
            whyNotLive = "Live intensity is off (Settings > Desk)."
            return
        }
        poll = Task { [weak self] in
            await self?.loadPatch()
            await self?.lookUpAddress(fixture)
            while !Task.isCancelled {
                guard let self else { return }
                guard let host = self.host() else {
                    self.whyNotLive = "Live levels need TitanDeck Host paired: it hears the sACN Titan sends."
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
                if self.slots(for: fixture) == nil {
                    // Not learnt yet: keep a fresh "before" for the next nudge.
                    await self.loadPatch()
                    let levels = await self.snapshot(host)
                    guard !Task.isCancelled, self.fixture == fixture else { return }
                    if let levels {
                        self.recent = (Date(), levels)
                        self.whyNotLive = self.whyNoChannels(fixture)
                    } else {
                        self.whyNotLive = Self.noSacn
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                } else {
                    await self.read(fixture)
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }
    }

    private static let noSacn = "TitanDeck Host doesn't hear any sACN from Titan. Titan needs sACN on its DMX lines (System > DMX Settings; it can sit alongside Art-Net or the DMX sockets)."

    /// Why the patch doesn't give this fixture's intensity channels.
    private func whyNoChannels(_ fixture: Int) -> String {
        guard usesPatchReport else {
            return "Use Titan's patch is off (Settings > Desk), so fixture \(fixture)'s intensity channel isn't known until the deck nudges it."
        }
        if let entry = patch[fixture] {
            return "Fixture \(fixture) is in Titan's patch at \(entry.universe).\(entry.address), but TitanDeck Host couldn't find its personality, so its intensity channel isn't known until the deck nudges it."
        }
        if patch.isEmpty {
            return patchProblem ?? "TitanDeck Host has no patch from Titan yet (CITP not linked, and no patch report)."
        }
        return "Fixture \(fixture) isn't in the patch TitanDeck Host has from Titan."
    }

    /// From Titan's patch, else (a fixture the patch doesn't know) learnt
    /// from a nudge. The patch is the show's as it is now; what was learnt
    /// may be from another show, with the fixture somewhere else.
    private func slots(for fixture: Int) -> [DmxSlot]? {
        patch[fixture].flatMap(IntensityLearning.slots(for:)) ?? learned[fixture]
    }

    /// The patch report, fetched again when it's more than 30 s old.
    private func loadPatch() async {
        guard usesPatchReport, let host = host() else { return }
        if let patchRead, Date().timeIntervalSince(patchRead) < 30 { return }
        patchRead = Date()
        guard let report = try? await host.patch() else {
            patchProblem = "TitanDeck Host didn't send a patch."
            note = "TitanDeck Host didn't send a patch (it needs Host 0.6 or later)."
            return
        }
        patchProblem = report.fixtures.isEmpty ? report.problem : nil
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
            raw = nil
            setLevel(nil)
            return
        }
        var snapshot: IntensityLearning.Snapshot = [:]
        for (universe, inUniverse) in Dictionary(grouping: slots, by: \.universe) {
            let first = inUniverse.map(\.address).min() ?? 1
            let last = inUniverse.map(\.address).max() ?? first
            let answer: HostDmxLevels
            do {
                answer = try await host.dmx(universe: universe, start: first, count: last - first + 1)
            } catch {
                guard !Task.isCancelled, self.fixture == fixture else { return }
                if case HostError.server(404, _) = error {
                    // The Host is there, but Titan isn't sending that universe as sACN.
                    raw = nil
                    setLevel(nil)
                    whyNotLive = "TitanDeck Host hears no sACN for universe \(universe), where fixture \(fixture)'s intensity is (\(Self.describe(slots))). Titan needs sACN on that DMX line (System > DMX Settings; it can sit alongside Art-Net or the DMX sockets)."
                    return
                }
                // The Host didn't answer: one missed read isn't worth
                // blanking the level for, a run of them is.
                misses += 1
                guard misses >= 3 else { return }
                raw = nil
                setLevel(nil)
                whyNotLive = "TitanDeck Host isn't answering, so there's no live level: \(error.localizedDescription)"
                return
            }
            var levels = [Int](repeating: 0, count: 512)
            for (offset, value) in answer.levels.enumerated() where answer.start - 1 + offset < 512 {
                levels[answer.start - 1 + offset] = value
            }
            snapshot[universe] = levels
        }
        guard !Task.isCancelled, self.fixture == fixture else { return }
        misses = 0
        raw = IntensityLearning.level(of: slots, in: snapshot)
        if let why = distrusted[fixture] {
            // Read, but not following the deck: not shown until it does.
            whyNotLive = why
            setLevel(nil)
            return
        }
        whyNotLive = raw == nil ? "The sACN for fixture \(fixture) couldn't be read." : nil
        setLevel(raw)
    }

    /// Every universe the Host hears, in full.
    private func snapshot(_ host: HostClient) async -> IntensityLearning.Snapshot? {
        guard let summary = try? await host.dmxSummary(), !summary.universes.isEmpty else {
            note = Self.noSacn
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
