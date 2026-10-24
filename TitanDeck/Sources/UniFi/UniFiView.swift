// UniFi/UniFiView.swift
import Charts
import SwiftUI

/// The show Wi-Fi from UniFi: this iPad's connection, the channel map with
/// neighbours, each access point's radios, and RF scans.
struct UniFiView: View {
    @ObservedObject var store: UniFiStore
    @State private var band: WiFiBand = .ghz5
    @State private var showingSetup = false
    @State private var scanTarget: UniFiDevice?

    var body: some View {
        NavigationStack {
            Group {
                if store.isConfigured {
                    dashboard
                } else {
                    ContentUnavailableView {
                        Label("Connect UniFi", systemImage: "wifi.router")
                    } description: {
                        Text("See your access points' channels, who's on which AP, neighbouring networks and RF scans. Uses a local UniFi admin login - no internet or API key.")
                    } actions: {
                        Button("Set Up UniFi") { showingSetup = true }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle("Wi-Fi")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("UniFi Setup", systemImage: "gearshape") { showingSetup = true }
                }
            }
            .sheet(isPresented: $showingSetup) { UniFiSetupView(store: store) }
            .confirmationDialog("Run an RF scan on \(scanTarget?.displayName ?? "this AP")?",
                                isPresented: Binding(get: { scanTarget != nil }, set: { if !$0 { scanTarget = nil } }),
                                titleVisibility: .visible, presenting: scanTarget) { ap in
                Button("Scan Now", role: .destructive) { Task { await store.startRFScan(ap) } }
            } message: { _ in
                Text("Its radios go off air for a few minutes while it listens, so everything on it drops off. Not during a show.")
            }
        }
    }

    private var dashboard: some View {
        List {
            Section { statusRow }
            if let me = store.thisDevice { Section("This iPad") { ThisDeviceCard(station: me, ap: store.accessPoint(mac: me.apMac)) } }

            Section {
                Picker("Band", selection: $band) {
                    ForEach(WiFiBand.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                ChannelMap(band: band, ourRadios: store.accessPoints.flatMap { ap in ap.radios.map { (name: ap.displayName, radio: $0) } },
                           neighbours: store.neighbours(in: band))
                    .frame(height: 220)
                quietest
            } header: {
                Text("Channels")
            } footer: {
                Text("Our access points as coloured blocks, neighbouring networks in grey (taller is louder). From what our APs hear, not a spectrum analyser.")
            }

            Section("Access points") {
                if store.accessPoints.isEmpty {
                    Text("No access points yet.").foregroundStyle(.secondary)
                }
                ForEach(store.accessPoints) { ap in
                    AccessPointCard(ap: ap, clients: store.clients(on: ap).count, scan: store.scans[ap.mac],
                                    isScanning: store.scanning.contains(ap.mac)) {
                        scanTarget = ap
                    } loadScan: {
                        Task { await store.loadScan(ap.mac) }
                    }
                }
            }

            if !store.weakClients.isEmpty {
                Section {
                    ForEach(store.weakClients.prefix(10)) { client in
                        StationRow(station: client, ap: store.accessPoint(mac: client.apMac))
                    }
                } header: {
                    Text("Weak signal")
                } footer: {
                    Text("Below -75 dBm. Move them closer, or add an AP nearer to them.")
                }
            }

            let nearby = store.neighbours(in: band)
            if !nearby.isEmpty {
                Section("Neighbours on \(band.title)") {
                    ForEach(nearby.prefix(15)) { NeighbourRow(neighbour: $0) }
                }
            }
        }
        .refreshable { await store.refresh() }
        .task { await store.keepRefreshing() }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.router.fill")
                .font(.title2)
                .foregroundStyle(statusColour)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle).font(.headline)
                Text(statusDetail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if case .connecting = store.status { ProgressView() }
        }
    }

    private var wlan: UniFiHealth? { store.health.first { $0.subsystem == "wlan" } }

    private var statusTitle: String {
        switch store.status {
        case .connected:
            let online = store.accessPoints.filter(\.isOnline).count
            return "\(online) of \(store.accessPoints.count) APs online · \(store.stations.count) on Wi-Fi"
        case .connecting: return "Connecting to \(store.address)..."
        case .failed: return "Can't reach UniFi"
        case .notSetUp: return "Not set up"
        }
    }

    private var statusDetail: String {
        switch store.status {
        case .connected(let date): "\(store.address) · updated \(date.formatted(date: .omitted, time: .standard))"
        case .failed(let message): message
        default: store.address
        }
    }

    private var statusColour: Color {
        switch store.status {
        case .connected: store.accessPoints.allSatisfy(\.isOnline) ? Color.green : Color.orange
        case .failed: Color.red
        default: Color.secondary
        }
    }

    @ViewBuilder
    private var quietest: some View {
        let width = band == .ghz2 ? 20 : (band == .ghz5 ? 40 : 80)
        let scores = ChannelAdvisor.scores(band: band, width: width, neighbours: store.neighbours(in: band), ourRadios: store.ourRadios)
        if !scores.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quietest channels").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(scores.prefix(band == .ghz2 ? 3 : 4)) { score in
                        VStack(spacing: 2) {
                            Text("\(score.channel)").font(.title3.weight(.bold).monospacedDigit())
                            Text(score.neighbours == 0 ? "clear" : "\(score.neighbours) near")
                                .font(.caption2).foregroundStyle(.secondary)
                            if score.isDFS {
                                Text("DFS").font(.caption2.weight(.bold)).foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.fill.quaternary, in: .rect(cornerRadius: 10))
                    }
                }
                Text(band == .ghz5 ? "DFS channels can be dropped if radar is detected - avoid them for a show-critical link." : "Suggestion only: check before changing a live show network.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Pieces

private struct ThisDeviceCard: View {
    let station: UniFiStation
    let ap: UniFiDevice?

    var body: some View {
        HStack(spacing: 16) {
            SignalBars(dBm: station.signal)
            VStack(alignment: .leading, spacing: 3) {
                Text(ap?.displayName ?? "Unknown AP").font(.headline)
                Text([station.band?.title, station.channel.map { "channel \($0)" }, station.radioProto.map { "Wi-Fi \($0.uppercased())" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(station.signal.map { "\($0) dBm" } ?? "-").font(.headline.monospacedDigit())
                if let rate = station.txRate {
                    Text("\(Int(rate / 1000)) Mbps").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SignalBars: View {
    let dBm: Int?

    private var level: Int {
        guard let dBm else { return 0 }
        switch dBm {
        case -55...: return 4
        case -65 ..< -55: return 3
        case -75 ..< -65: return 2
        default: return 1
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1 ... 4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 2)
                    .fill(bar <= level ? colour : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: CGFloat(6 + bar * 6))
            }
        }
        .accessibilityLabel("Signal \(dBm.map { "\($0) dBm" } ?? "unknown")")
    }

    private var colour: Color { level >= 3 ? .green : (level == 2 ? .orange : .red) }
}

private struct AccessPointCard: View {
    let ap: UniFiDevice
    let clients: Int
    let scan: UniFiSpectrumScan?
    let isScanning: Bool
    let startScan: () -> Void
    let loadScan: () -> Void
    @State private var showingScan = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(ap.isOnline ? Color.green : Color.red).frame(width: 9, height: 9)
                Text(ap.displayName).font(.headline)
                Text(ap.model ?? "").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Label("\(clients)", systemImage: "person.2.fill").font(.callout.monospacedDigit())
            }
            ForEach(ap.radios) { radio in
                HStack(spacing: 10) {
                    Text(radio.band.title)
                        .font(.caption.weight(.bold))
                        .frame(width: 58, alignment: .leading)
                    Text(radio.channel.map { "ch \($0)" } ?? "ch -")
                        .font(.callout.monospacedDigit())
                        .frame(width: 54, alignment: .leading)
                    Text(radio.width.map { "\($0) MHz" } ?? "")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .leading)
                    Gauge(value: Double(radio.utilisation ?? 0), in: 0 ... 100) {
                        EmptyView()
                    } currentValueLabel: {
                        Text("\(radio.utilisation ?? 0)%")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(utilisationColour(radio.utilisation))
                    Text(radio.txPower.map { "\($0) dBm" } ?? "")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 54, alignment: .trailing)
                }
            }
            HStack {
                if isScanning {
                    ProgressView().controlSize(.small)
                    Text("RF scan running...").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("RF Scan", systemImage: "waveform.badge.magnifyingglass", action: startScan)
                        .disabled(!ap.isOnline)
                    Button(scan == nil ? "Last Scan" : (showingScan ? "Hide Scan" : "Show Scan"), systemImage: "chart.bar") {
                        if scan == nil { loadScan() }
                        withAnimation { showingScan.toggle() }
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            if showingScan, let scan {
                SpectrumChart(scan: scan)
            }
        }
        .padding(.vertical, 4)
    }

    private func utilisationColour(_ value: Int?) -> Color {
        switch value ?? 0 {
        case ..<40: Color.green
        case 40 ..< 70: Color.orange
        default: Color.red
        }
    }
}

/// An RF scan: airtime busy per channel, with the non-Wi-Fi share on top.
private struct SpectrumChart: View {
    let scan: UniFiSpectrumScan

    var body: some View {
        let byBand = scan.entriesByBand
        VStack(alignment: .leading, spacing: 8) {
            if byBand.isEmpty {
                Text("No scan results yet. Run an RF scan (here or in UniFi).").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(byBand.keys.sorted(), id: \.self) { band in
                Text(band.title).font(.caption.weight(.bold))
                Chart(byBand[band] ?? [], id: \.channel) { entry in
                    BarMark(x: .value("Channel", "\(entry.channel ?? 0)"), y: .value("Busy", entry.utilization ?? 0))
                        .foregroundStyle(.blue.opacity(0.7))
                    BarMark(x: .value("Channel", "\(entry.channel ?? 0)"), y: .value("Interference", entry.interference ?? 0))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .chartYScale(domain: 0.0 ... 100.0)
                .chartYAxisLabel("% busy")
                .frame(height: 120)
            }
            if let date = scan.lastScanned {
                Text("Scanned \(date.formatted(.relative(presentation: .named))). Blue: Wi-Fi traffic, red: interference.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Our radios as blocks across the band, neighbours as grey bars by signal.
private struct ChannelMap: View {
    let band: WiFiBand
    let ourRadios: [(name: String, radio: UniFiDevice.RadioSummary)]
    let neighbours: [UniFiNeighbour]

    private struct Block: Identifiable {
        let id: String
        let label: String
        let low: Int
        let high: Int
        let strength: Double
        let ours: Bool
    }

    private var blocks: [Block] {
        var result: [Block] = []
        for neighbour in neighbours.prefix(60) {
            guard let channel = neighbour.channel, let dBm = neighbour.dBm else { continue }
            let span = ChannelSpan.of(band: band, channel: channel, width: 20)
            result.append(Block(id: neighbour.id, label: neighbour.essid ?? "", low: span.low, high: span.high,
                                strength: Double(max(0, dBm + 100)), ours: false))
        }
        for (index, entry) in ourRadios.enumerated() where entry.radio.band == band {
            guard let span = entry.radio.span else { continue }
            result.append(Block(id: "ours-\(index)", label: entry.name, low: span.low, high: span.high, strength: 70, ours: true))
        }
        return result
    }

    private var domain: ClosedRange<Double> {
        switch band {
        case .ghz2: 2400 ... 2495
        case .ghz5: 5150 ... 5895
        case .ghz6: 5925 ... 7125
        }
    }

    var body: some View {
        Chart(blocks) { block in
            RectangleMark(xStart: .value("Low", Double(block.low)), xEnd: .value("High", Double(block.high)),
                          yStart: .value("Floor", 0.0), yEnd: .value("Signal", block.strength))
                .foregroundStyle(block.ours ? AnyShapeStyle(Color.accentColor.opacity(0.55)) : AnyShapeStyle(Color.gray.opacity(0.25)))
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    if block.ours {
                        Text(block.label).font(.system(size: 9, weight: .semibold)).lineLimit(1)
                    }
                }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0.0 ... 80.0)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: band.candidateChannels.map { Double(band.frequency(channel: $0)) }) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let mhz = value.as(Double.self), let channel = band.candidateChannels.first(where: { Double(band.frequency(channel: $0)) == mhz }) {
                        Text("\(channel)").font(.system(size: 9))
                    }
                }
            }
        }
    }
}

private struct StationRow: View {
    let station: UniFiStation
    let ap: UniFiDevice?

    var body: some View {
        HStack {
            SignalBars(dBm: station.signal)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.displayName).font(.callout.weight(.medium))
                Text("on \(ap?.displayName ?? "?") · \(station.band?.title ?? "") ch \(station.channel.map(String.init) ?? "-")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(station.signal.map { "\($0) dBm" } ?? "").font(.callout.monospacedDigit())
        }
    }
}

private struct NeighbourRow: View {
    let neighbour: UniFiNeighbour

    var body: some View {
        HStack {
            SignalBars(dBm: neighbour.dBm)
            VStack(alignment: .leading, spacing: 2) {
                Text(neighbour.essid?.isEmpty == false ? neighbour.essid! : "Hidden network").font(.callout.weight(.medium))
                Text(neighbour.bssid).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(neighbour.channel.map { "ch \($0)" } ?? "").font(.callout.monospacedDigit())
                Text(neighbour.dBm.map { "\($0) dBm" } ?? "").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }
}
