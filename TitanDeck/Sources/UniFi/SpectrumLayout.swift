// UniFi/SpectrumLayout.swift
import Foundation

/// Where things go on the Wi-Fi channel map, worked out so nothing overlaps:
/// our access points each get a lane (with room for their name), channel
/// numbers and neighbour names are thinned to what fits. Pure, so it's tested.
enum SpectrumLayout {
    /// The part of the band drawn, in MHz.
    static func domain(_ band: WiFiBand) -> ClosedRange<Double> {
        switch band {
        case .ghz2: 2400 ... 2495
        case .ghz5: 5150 ... 5895
        case .ghz6: 5925 ... 7125
        }
    }

    /// Points across `width` for a frequency.
    static func x(_ mhz: Double, in domain: ClosedRange<Double>, width: Double) -> Double {
        (mhz - domain.lowerBound) / (domain.upperBound - domain.lowerBound) * width
    }

    /// A lane for each item (its extent in points, label included), in the
    /// order given: the first lane where it stays `gap` clear of everything
    /// already there. Items are placed left to right, so the result doesn't
    /// depend on the order they came in.
    static func lanes(_ items: [ClosedRange<Double>], gap: Double = 6) -> [Int] {
        var laneEnds: [Double] = []
        var result = Array(repeating: 0, count: items.count)
        for index in items.indices.sorted(by: { items[$0].lowerBound < items[$1].lowerBound }) {
            let item = items[index]
            if let free = laneEnds.firstIndex(where: { $0 + gap <= item.lowerBound }) {
                result[index] = free
                laneEnds[free] = item.upperBound
            } else {
                result[index] = laneEnds.count
                laneEnds.append(item.upperBound)
            }
        }
        return result
    }

    /// Which labels to show: each is `widths[i]` wide, centred on
    /// `centres[i]`. Higher priority first (then left to right); a label is
    /// kept only if it stays `gap` clear of those already kept and inside
    /// 0...`limit`. Returns the indices kept.
    static func thinned(centres: [Double], widths: [Double], priority: [Int], gap: Double = 4,
                        limit: Double = .infinity) -> Set<Int> {
        var kept: [ClosedRange<Double>] = []
        var result: Set<Int> = []
        let order = centres.indices.sorted { a, b in
            priority[a] != priority[b] ? priority[a] > priority[b] : centres[a] < centres[b]
        }
        for index in order {
            let low = centres[index] - widths[index] / 2
            let high = centres[index] + widths[index] / 2
            guard low >= 0, high <= limit else { continue }
            guard !kept.contains(where: { low < $0.upperBound + gap && $0.lowerBound < high + gap }) else { continue }
            kept.append(low ... high)
            result.insert(index)
        }
        return result
    }

    /// Channels along the axis, and how much each matters for a label:
    /// 2 = where people look first (1/6/11, the start of each 5 GHz block),
    /// 1 = the usual picks, 0 = the rest.
    static func axisChannels(_ band: WiFiBand) -> [(channel: Int, priority: Int)] {
        switch band {
        case .ghz2:
            return (1 ... 13).map { ($0, [1, 6, 11].contains($0) ? 2 : 0) }
        case .ghz5:
            let starts: Set = [36, 52, 100, 149]
            let picks: Set = [44, 60, 108, 116, 124, 132, 140, 157, 165]
            return band.candidateChannels.map { ($0, starts.contains($0) ? 2 : (picks.contains($0) ? 1 : 0)) }
        case .ghz6:
            return band.candidateChannels.enumerated().map { ($1, $0.isMultiple(of: 2) ? 2 : 1) }
        }
    }

    /// Roughly how wide a line of text is, in points.
    static func textWidth(_ text: String, size: Double) -> Double {
        Double(text.count) * size * 0.6 + 2
    }

    /// Pairs of our radios (by name) on the same band whose channels overlap.
    static func clashes(_ radios: [(name: String, span: ChannelSpan)]) -> [(String, String)] {
        var result: [(String, String)] = []
        for i in radios.indices {
            for j in radios.indices where j > i && radios[i].name != radios[j].name && radios[i].span.overlaps(radios[j].span) {
                result.append((radios[i].name, radios[j].name))
            }
        }
        return result
    }

    /// 0 (the noise floor, -95 dBm) to 1 (very loud, -30 dBm and up).
    static func loudness(dBm: Int) -> Double {
        min(max(Double(dBm + 95) / 65, 0), 1)
    }
}
