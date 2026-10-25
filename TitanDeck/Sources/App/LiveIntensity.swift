// App/LiveIntensity.swift
import Foundation

/// One DMX channel: universe and address, both 1-based.
struct DmxSlot: Codable, Hashable {
    var universe: Int
    var address: Int
}

/// Works out which DMX channels are a fixture's intensity by watching the
/// sACN Titan sends while the deck changes that fixture's level: the channels
/// that move the way the deck moved it. No Patch needed. Pure, so it's tested.
enum IntensityLearning {
    /// Levels per universe, 512 each (slot 1 at index 0).
    typealias Snapshot = [Int: [Int]]

    /// Smaller changes than this (about 1%) are jitter.
    static let minimumStep = 3
    /// More channels than this moving means something else is going on (a cue).
    static let maximumChannels = 8

    /// The channels that moved up (or down) between the two snapshots.
    /// `near` narrows the search to a fixture's patch address. One channel
    /// moving the other way is allowed (the fine half of a 16-bit dimmer);
    /// more than that, or nothing moving, gives nil: try again next time.
    static func channels(before: Snapshot, after: Snapshot, rising: Bool,
                         near: DmxAddress? = nil, span: Int = 64) -> [DmxSlot]? {
        var with: [DmxSlot] = []
        var against = 0
        for (universe, old) in before {
            guard let new = after[universe] else { continue }
            if let near, near.universe != universe { continue }
            let count = min(old.count, new.count)
            let range = near.map { max($0.address - 1, 0) ..< min($0.address - 1 + span, count) } ?? 0 ..< count
            for i in range {
                let step = new[i] - old[i]
                guard abs(step) >= minimumStep else { continue }
                if (step > 0) == rising {
                    with.append(DmxSlot(universe: universe, address: i + 1))
                } else {
                    against += 1
                }
            }
        }
        guard !with.isEmpty, with.count <= maximumChannels, against <= 1 else { return nil }
        return with.sorted { ($0.universe, $0.address) < ($1.universe, $1.address) }
    }

    /// The fixture's level, 0...1. Two neighbouring channels are taken as a
    /// 16-bit dimmer (the first is the coarse one); otherwise the brightest
    /// channel (an RGB fixture with no dimmer: its brightest colour).
    static func level(of slots: [DmxSlot], in snapshot: Snapshot) -> Double? {
        let values = slots.compactMap { slot -> Int? in
            guard let levels = snapshot[slot.universe], levels.indices.contains(slot.address - 1) else { return nil }
            return levels[slot.address - 1]
        }
        guard values.count == slots.count, let first = values.first else { return nil }
        let pair = slots.count == 2 && slots[0].universe == slots[1].universe && slots[1].address == slots[0].address + 1
        return Double(pair ? first : values.max() ?? first) / 255
    }

    /// A fixture's intensity channels from Titan's patch report, or nil when
    /// the Host doesn't know them (no personality found) or they'd run off
    /// the universe.
    static func slots(for fixture: HostPatchFixture) -> [DmxSlot]? {
        guard let offsets = fixture.intensity, !offsets.isEmpty else { return nil }
        let slots = offsets.map { DmxSlot(universe: fixture.universe, address: fixture.address + $0) }
        return slots.allSatisfy({ (1 ... 512).contains($0.address) }) ? slots : nil
    }

    /// Which way an action moves the selected fixture's level, or nil if it
    /// doesn't (or can't be told).
    static func direction(of action: TitanAction) -> Bool? {
        switch action {
        case .adjustIntensity(let percent): return percent == 0 ? nil : percent > 0
        case .dimmerFlash(let down, _): return !down
        default: return nil
        }
    }
}
