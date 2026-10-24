// UniFi/UniFiModels.swift
import Foundation

/// The UniFi Network controller's local ("classic") API, reached with a
/// local admin's username and password - no API key or internet needed.
/// Shapes match UniFi Network 8-9 (also what its own web UI reads). Every
/// field is optional or lenient: the API isn't documented and changes.
enum UniFiAPI {
    /// UniFi OS consoles (Dream Machine, Cloud Gateway, Cloud Key Gen2+) put
    /// the Network app behind /proxy/network; the old standalone controller
    /// (usually port 8443) doesn't.
    enum Flavour: String, Codable {
        case unifiOS
        case legacy
    }

    static func loginPath(_ flavour: Flavour) -> String {
        flavour == .unifiOS ? "/api/auth/login" : "/api/login"
    }

    /// "/proxy/network/api/s/default/stat/device".
    static func sitePath(_ flavour: Flavour, site: String, _ path: String) -> String {
        let prefix = flavour == .unifiOS ? "/proxy/network" : ""
        let cleanSite = site.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/", with: "")
        return "\(prefix)/api/s/\(cleanSite.isEmpty ? "default" : cleanSite)/\(path)"
    }

    /// "https://10.0.0.1" or "https://unifi.local:8443", from what was typed.
    static func baseURL(_ address: String) -> URL? {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text), components.host?.isEmpty == false else { return nil }
        components.scheme = "https"
        components.path = ""
        components.query = nil
        return components.url
    }

    /// `{"meta": {"rc": "ok"}, "data": [...]}`.
    struct Envelope<T: Decodable>: Decodable {
        struct Meta: Decodable {
            var rc: String?
            var msg: String?
        }

        var meta: Meta?
        var data: [T]

        private enum CodingKeys: String, CodingKey { case meta, data }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            meta = try c.decodeIfPresent(Meta.self, forKey: .meta)
            data = (try? c.decode(LossyArray<T>.self, forKey: .data).items) ?? []
        }
    }

    static let decoder = JSONDecoder()
}

/// Decodes what it can and skips entries that don't fit, so one odd device
/// doesn't hide the rest.
struct LossyArray<T: Decodable>: Decodable {
    let items: [T]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items: [T] = []
        while !container.isAtEnd {
            if let item = try? container.decode(T.self) {
                items.append(item)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        self.items = items
    }

    private struct Skip: Decodable {}
}

/// A number the API sometimes sends as text ("auto", "80", "VHT80").
struct FlexibleInt: Decodable, Equatable {
    let value: Int?

    init(_ value: Int?) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let int = try? c.decode(Int.self) {
            value = int
        } else if let double = try? c.decode(Double.self) {
            value = Int(double)
        } else if let text = try? c.decode(String.self) {
            value = Int(text.filter(\.isNumber))
        } else {
            value = nil
        }
    }
}

// MARK: - Bands and channels

enum WiFiBand: String, CaseIterable, Identifiable, Comparable {
    case ghz2 = "ng"
    case ghz5 = "na"
    case ghz6 = "6e"

    var id: Self { self }

    init?(radio: String?) {
        switch radio?.lowercased() {
        case "ng", "2g", "2.4": self = .ghz2
        case "na", "5g", "5": self = .ghz5
        case "6e", "6g", "6": self = .ghz6
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .ghz2: "2.4 GHz"
        case .ghz5: "5 GHz"
        case .ghz6: "6 GHz"
        }
    }

    /// Centre frequency in MHz of a 20 MHz channel.
    func frequency(channel: Int) -> Int {
        switch self {
        case .ghz2: channel == 14 ? 2484 : 2407 + 5 * channel
        case .ghz5: 5000 + 5 * channel
        case .ghz6: 5950 + 5 * channel
        }
    }

    /// Channels worth considering when picking one.
    var candidateChannels: [Int] {
        switch self {
        case .ghz2: [1, 6, 11]
        case .ghz5: [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 149, 153, 157, 161, 165]
        case .ghz6: [5, 21, 37, 53, 69, 85, 101, 117, 133, 149, 165, 181, 197, 213, 229]   // preferred scanning channels
        }
    }

    /// 5 GHz channels that need radar detection (DFS) and can be kicked off.
    static func isDFS(_ channel: Int) -> Bool { (52 ... 144).contains(channel) }

    static func < (a: WiFiBand, b: WiFiBand) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// The frequency span a channel occupies at a width.
struct ChannelSpan: Equatable {
    let low: Int
    let high: Int

    var centre: Double { Double(low + high) / 2 }

    func overlaps(_ other: ChannelSpan) -> Bool { low < other.high && other.low < high }

    /// A 2.4 GHz channel is ~22 MHz wide whatever it's set to (20 MHz), so its
    /// neighbours overlap. Wider 5/6 GHz channels are blocks of 20 MHz ones,
    /// aligned to the band's channel plan.
    static func of(band: WiFiBand, channel: Int, width: Int?) -> ChannelSpan {
        let width = max(20, width ?? 20)
        let centre = band.frequency(channel: channel)
        switch band {
        case .ghz2:
            // 22 MHz per channel; a 40 MHz channel bonds the one 20 MHz above.
            return width >= 40 ? ChannelSpan(low: centre - 11, high: centre + 31)
                : ChannelSpan(low: centre - 11, high: centre + 11)
        case .ghz5, .ghz6:
            // Bottom edge of the band's channel plan: channel 36, or 149 for the
            // upper 5 GHz block (offset 5 MHz from the rest), or 6 GHz channel 1.
            let base = band == .ghz6 ? 5945 : (channel >= 149 ? 5735 : 5170)
            let blockStart = base + ((centre - 10 - base) / width) * width
            return ChannelSpan(low: blockStart, high: blockStart + width)
        }
    }
}

// MARK: - Devices (access points)

struct UniFiDevice: Decodable, Identifiable, Equatable {
    struct Radio: Decodable, Equatable {
        var name: String?
        var radio: String?
        var channel: FlexibleInt?
        /// Channel width in MHz ("ht").
        var ht: FlexibleInt?
        var txPowerMode: String?

        private enum CodingKeys: String, CodingKey {
            case name, radio, channel, ht
            case txPowerMode = "tx_power_mode"
        }
    }

    struct RadioStats: Decodable, Equatable {
        var name: String?
        var radio: String?
        var channel: FlexibleInt?
        var txPower: FlexibleInt?
        /// Channel utilisation, percent: everything the radio hears, ours and theirs.
        var cuTotal: FlexibleInt?
        var cuSelfRx: FlexibleInt?
        var cuSelfTx: FlexibleInt?
        var numSta: Int?
        var satisfaction: Int?
        var state: String?

        private enum CodingKeys: String, CodingKey {
            case name, radio, channel, satisfaction, state
            case txPower = "tx_power"
            case cuTotal = "cu_total"
            case cuSelfRx = "cu_self_rx"
            case cuSelfTx = "cu_self_tx"
            case numSta = "num_sta"
        }
    }

    struct Vap: Decodable, Equatable {
        var essid: String?
        var bssid: String?
        var radio: String?
        var numSta: Int?

        private enum CodingKeys: String, CodingKey {
            case essid, bssid, radio
            case numSta = "num_sta"
        }
    }

    var mac: String
    var name: String?
    var model: String?
    var type: String?
    var state: Int?
    var version: String?
    var ip: String?
    var uptime: Double?
    var numSta: Int?
    var satisfaction: Int?
    var radioTable: [Radio]?
    var radioTableStats: [RadioStats]?
    var vapTable: [Vap]?
    var spectrumScanning: Bool?

    var id: String { mac }
    var displayName: String { (name?.isEmpty == false ? name : nil) ?? model ?? mac }
    var isAccessPoint: Bool { type == "uap" || radioTable?.isEmpty == false }
    /// State 1 is connected; anything else is offline, adopting, upgrading...
    var isOnline: Bool { state == 1 }

    private enum CodingKeys: String, CodingKey {
        case mac, name, model, type, state, version, ip, uptime, satisfaction
        case numSta = "num_sta"
        case radioTable = "radio_table"
        case radioTableStats = "radio_table_stats"
        case vapTable = "vap_table"
        case spectrumScanning = "spectrum_scanning"
    }

    /// One radio pulled together from the device's three tables.
    struct RadioSummary: Identifiable, Equatable {
        let band: WiFiBand
        let channel: Int?
        let width: Int?
        let txPower: Int?
        let utilisation: Int?
        let clients: Int
        let satisfaction: Int?
        let bssids: [String]
        var id: WiFiBand { band }

        var span: ChannelSpan? { channel.map { ChannelSpan.of(band: band, channel: $0, width: width) } }
    }

    var radios: [RadioSummary] {
        (radioTable ?? []).compactMap { radio -> RadioSummary? in
            guard let band = WiFiBand(radio: radio.radio) else { return nil }
            let stats = radioTableStats?.first { $0.name == radio.name } ?? radioTableStats?.first { WiFiBand(radio: $0.radio) == band }
            let vaps = (vapTable ?? []).filter { WiFiBand(radio: $0.radio) == band }
            return RadioSummary(band: band,
                                channel: stats?.channel?.value ?? radio.channel?.value,
                                width: radio.ht?.value,
                                txPower: stats?.txPower?.value,
                                utilisation: stats?.cuTotal?.value,
                                clients: stats?.numSta ?? vaps.reduce(0) { $0 + ($1.numSta ?? 0) },
                                satisfaction: stats?.satisfaction.flatMap { $0 >= 0 ? $0 : nil },
                                bssids: vaps.compactMap { $0.bssid?.uppercased() })
        }
        .sorted { $0.band < $1.band }
    }
}

// MARK: - Clients (stations)

struct UniFiStation: Decodable, Identifiable, Equatable {
    var mac: String
    var hostname: String?
    var name: String?
    var ip: String?
    var essid: String?
    var apMac: String?
    var channel: Int?
    var radio: String?
    var radioProto: String?
    /// dBm, negative.
    var signal: Int?
    var rssi: Int?
    var txRate: Double?
    var satisfaction: Int?
    var isWired: Bool?

    var id: String { mac }
    var displayName: String { (name?.isEmpty == false ? name : nil) ?? hostname ?? mac }
    var band: WiFiBand? { WiFiBand(radio: radio) }

    private enum CodingKeys: String, CodingKey {
        case mac, hostname, name, ip, essid, channel, radio, signal, rssi, satisfaction
        case apMac = "ap_mac"
        case radioProto = "radio_proto"
        case txRate = "tx_rate"
        case isWired = "is_wired"
    }
}

// MARK: - Neighbouring networks

struct UniFiNeighbour: Decodable, Identifiable, Equatable {
    var bssid: String
    var essid: String?
    var channel: Int?
    var radio: String?
    var band: String?
    var freq: Int?
    /// dBm if the controller sends it; otherwise worked out from rssi.
    var signal: Int?
    var rssi: Int?
    /// Which of our APs heard it.
    var apMac: String?
    var isRogue: Bool?

    var id: String { bssid + (apMac ?? "") }

    var wifiBand: WiFiBand? {
        if let band = WiFiBand(radio: radio ?? band) { return band }
        guard let freq else { return nil }
        if freq < 3000 { return .ghz2 }
        return freq < 5925 ? .ghz5 : .ghz6
    }

    /// Signal in dBm. UniFi's rssi is the level above a -95 dBm floor.
    var dBm: Int? {
        if let signal, signal < 0 { return signal }
        return rssi.map { $0 > 0 ? $0 - 95 : $0 }
    }

    private enum CodingKeys: String, CodingKey {
        case bssid, essid, channel, radio, band, freq, signal, rssi
        case apMac = "ap_mac"
        case isRogue = "is_rogue"
    }
}

// MARK: - Health and RF scan

struct UniFiHealth: Decodable, Equatable {
    var subsystem: String
    var status: String?
    var numAp: Int?
    var numUser: Int?
    var numGuest: Int?
    var numDisconnected: Int?

    private enum CodingKeys: String, CodingKey {
        case subsystem, status
        case numAp = "num_ap"
        case numUser = "num_user"
        case numGuest = "num_guest"
        case numDisconnected = "num_disconnected"
    }
}

/// An AP's RF environment scan (the radios go off air while it runs).
struct UniFiSpectrumScan: Decodable, Equatable {
    struct Entry: Decodable, Equatable {
        var channel: Int?
        var width: FlexibleInt?
        var freq: Int?
        /// Percent of airtime busy.
        var utilization: Double?
        /// Percent of airtime lost to non-Wi-Fi interference.
        var interference: Double?
    }

    struct Scan: Decodable, Equatable {
        var radio: String?
        var spectrumTable: [Entry]?
        var spectrumTableTime: Double?

        private enum CodingKeys: String, CodingKey {
            case radio
            case spectrumTable = "spectrum_table"
            case spectrumTableTime = "spectrum_table_time"
        }
    }

    var mac: String?
    var spectrumScanning: Bool?
    var scans: [Scan]?
    /// Older controllers put one table at the top level.
    var spectrumTable: [Entry]?

    private enum CodingKeys: String, CodingKey {
        case mac, scans
        case spectrumScanning = "spectrum_scanning"
        case spectrumTable = "spectrum_table"
    }

    /// Entries by band, from either layout.
    var entriesByBand: [WiFiBand: [Entry]] {
        var result: [WiFiBand: [Entry]] = [:]
        for scan in scans ?? [] {
            guard let band = WiFiBand(radio: scan.radio) else { continue }
            result[band, default: []] += scan.spectrumTable ?? []
        }
        for entry in spectrumTable ?? [] {
            guard let freq = entry.freq else { continue }
            let band: WiFiBand = freq < 3000 ? .ghz2 : (freq < 5925 ? .ghz5 : .ghz6)
            result[band, default: []].append(entry)
        }
        return result
    }

    var lastScanned: Date? {
        (scans ?? []).compactMap(\.spectrumTableTime).max().map { Date(timeIntervalSince1970: $0 > 1e11 ? $0 / 1000 : $0) }
    }
}

// MARK: - Channel advice

/// Which channel is quietest in a band, from what our APs hear (neighbours
/// and their signal) and what our own APs are using.
enum ChannelAdvisor {
    struct Score: Equatable, Identifiable {
        let channel: Int
        /// Lower is better: neighbours' signal weight on this channel.
        let load: Double
        let neighbours: Int
        let ourAPs: Int
        let isDFS: Bool
        var id: Int { channel }
    }

    /// Neighbour weight from signal: -50 dBm counts ~100x more than -70 dBm.
    static func weight(dBm: Int) -> Double { pow(10, Double(dBm + 90) / 20) }

    static func scores(band: WiFiBand, width: Int = 20, neighbours: [UniFiNeighbour],
                       ourRadios: [UniFiDevice.RadioSummary]) -> [Score] {
        band.candidateChannels.map { channel in
            let span = ChannelSpan.of(band: band, channel: channel, width: width)
            var load = 0.0
            var count = 0
            for neighbour in neighbours where neighbour.wifiBand == band {
                guard let other = neighbour.channel, let dBm = neighbour.dBm else { continue }
                if ChannelSpan.of(band: band, channel: other, width: 20).overlaps(span) {
                    load += weight(dBm: dBm)
                    count += 1
                }
            }
            let ours = ourRadios.filter { $0.band == band && ($0.span?.overlaps(span) ?? false) }.count
            load += Double(ours) * weight(dBm: -55)   // our own APs on the same channel matter most
            return Score(channel: channel, load: load, neighbours: count, ourAPs: ours,
                         isDFS: band == .ghz5 && WiFiBand.isDFS(channel))
        }
        .sorted { ($0.load, $0.isDFS ? 1 : 0, $0.channel) < ($1.load, $1.isDFS ? 1 : 0, $1.channel) }
    }
}
