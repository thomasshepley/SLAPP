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
                    .padding(.vertical, 4)
                quietest
            } header: {
                Text("Channels")
            } footer: {
                Text("Neighbouring networks as grey hills (taller is louder, dBm on the left), our access points' channels shaded in their colours with each radio on its own row below. From what our APs hear, not a spectrum analyser.")
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
        if dBm >= -55 { return 4 }
        if dBm >= -65 { return 3 }
        if dBm >= -75 { return 2 }
        return 1
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
                SpectrumChart(scan: scan, radios: ap.radios)
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

/// An RF scan: how busy each channel's airtime was, with the share lost to
/// non-Wi-Fi interference in red, and this AP's own channel shaded behind.
private struct SpectrumChart: View {
    let scan: UniFiSpectrumScan
    let radios: [UniFiDevice.RadioSummary]

    private struct Bar: Identifiable {
        let id: Int
        let channel: Int
        let span: ChannelSpan
        let busy: Double
        let interference: Double
    }

    var body: some View {
        let byBand = scan.entriesByBand
        VStack(alignment: .leading, spacing: 14) {
            if byBand.isEmpty {
                Text("No scan results yet. Run an RF scan (here or in UniFi).").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(byBand.keys.sorted(), id: \.self) { band in
                bandChart(band, entries: byBand[band] ?? [])
            }
            HStack(spacing: 14) {
                key(.blue, "Wi-Fi busy")
                key(.red, "Interference")
                key(.accentColor.opacity(0.25), "This AP")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            if let date = scan.lastScanned {
                Text("Scanned \(date.formatted(.relative(presentation: .named))).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.fill.quinary, in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private func bandChart(_ band: WiFiBand, entries: [UniFiSpectrumScan.Entry]) -> some View {
        let bars = entries.enumerated().compactMap { index, entry -> Bar? in
            guard let channel = entry.channel else { return nil }
            return Bar(id: index, channel: channel, span: ChannelSpan.of(band: band, channel: channel, width: 20),
                       busy: min(max(entry.utilization ?? 0, 0), 100),
                       interference: min(max(entry.interference ?? 0, 0), 100))
        }
        let ours = radios.first { $0.band == band }?.span
        let quietest = bars.min { $0.busy < $1.busy }
        let labelled = SpectrumLayout.axisChannels(band).filter { $0.priority >= (band == .ghz2 ? 2 : 1) }.map(\.channel)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(band.title).font(.subheadline.weight(.semibold))
                Spacer()
                if let quietest {
                    Text("Quietest: ch \(quietest.channel), \(Int(quietest.busy.rounded()))% busy")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Chart {
                if let ours {
                    RectangleMark(xStart: .value("Low", Double(ours.low)), xEnd: .value("High", Double(ours.high)),
                                  yStart: .value("Floor", 0.0), yEnd: .value("Top", 100.0))
                        .foregroundStyle(Color.accentColor.opacity(0.15))
                }
                ForEach(bars) { bar in
                    RectangleMark(xStart: .value("Low", Double(bar.span.low) + 2), xEnd: .value("High", Double(bar.span.high) - 2),
                                  yStart: .value("Floor", 0.0), yEnd: .value("Busy", max(bar.busy, bar.interference)))
                        .foregroundStyle(Color.blue.opacity(0.75))
                        .cornerRadius(3)
                    if bar.interference > 0 {
                        RectangleMark(xStart: .value("Low", Double(bar.span.low) + 2), xEnd: .value("High", Double(bar.span.high) - 2),
                                      yStart: .value("Floor", 0.0), yEnd: .value("Interference", bar.interference))
                            .foregroundStyle(Color.red.opacity(0.85))
                            .cornerRadius(3)
                    }
                }
            }
            .chartXScale(domain: SpectrumLayout.domain(band))
            .chartYScale(domain: 0.0 ... 100.0)
            .chartXAxis {
                AxisMarks(values: labelled.map { Double(band.frequency(channel: $0)) }) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let mhz = value.as(Double.self), let channel = labelled.first(where: { Double(band.frequency(channel: $0)) == mhz }) {
                            Text("\(channel)").font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0.0, 50.0, 100.0]) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let percent = value.as(Double.self) { Text("\(Int(percent))%").font(.caption2.monospacedDigit()) }
                    }
                }
            }
            .frame(height: 140)
        }
    }

    private func key(_ colour: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 10, height: 10)
            Text(title)
        }
    }
}

/// The band as a picture: neighbouring networks as grey hills (taller is
/// louder) with the loudest named, our access points' channels shaded in
/// their colours, then each of our radios on its own lane underneath, so no
/// two names ever sit on top of each other.
private struct ChannelMap: View {
    let band: WiFiBand
    let ourRadios: [(name: String, radio: UniFiDevice.RadioSummary)]
    let neighbours: [UniFiNeighbour]
    @State private var width: CGFloat = 600

    private static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .yellow, .indigo]
    private static let landscapeHeight: CGFloat = 120
    private static let axisHeight: CGFloat = 20
    private static let laneHeight: CGFloat = 26
    private static let laneFont: CGFloat = 11
    private static let axisFont: CGFloat = 10
    private static let neighbourFont: CGFloat = 9
    private static let gutter: CGFloat = 28

    private struct Ours: Identifiable {
        let id: Int
        let name: String
        let label: String
        let span: ChannelSpan
        let colour: Color
    }

    private struct Placed {
        let ours: Ours
        let x0: CGFloat
        let x1: CGFloat
        let lane: Int
        /// Where the name goes: inside the bar, or to its right or left.
        let labelX: CGFloat
        let inside: Bool
    }

    private var ours: [Ours] {
        let names = ourRadios.map(\.name).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return ourRadios.enumerated().compactMap { index, entry in
            guard entry.radio.band == band, let span = entry.radio.span, let channel = entry.radio.channel else { return nil }
            let colour = Self.palette[(names.firstIndex(of: entry.name) ?? 0) % Self.palette.count]
            let widthText = entry.radio.width.map { " · \($0) MHz" } ?? ""
            return Ours(id: index, name: entry.name, label: "\(entry.name)  ch \(channel)\(widthText)", span: span, colour: colour)
        }
    }

    /// Our radios on lanes, worked out for the current width.
    private func placed(plotWidth: CGFloat) -> [Placed] {
        let domain = SpectrumLayout.domain(band)
        let items = ours.map { item -> (Ours, CGFloat, CGFloat, CGFloat, Bool, ClosedRange<Double>) in
            let x0 = CGFloat(SpectrumLayout.x(Double(item.span.low), in: domain, width: Double(plotWidth)))
            let x1 = CGFloat(SpectrumLayout.x(Double(item.span.high), in: domain, width: Double(plotWidth)))
            let text = CGFloat(SpectrumLayout.textWidth(item.label, size: Double(Self.laneFont)))
            if x1 - x0 >= text + 12 {
                return (item, x0, x1, (x0 + x1) / 2, true, Double(x0) ... Double(x1))
            }
            if x1 + 6 + text <= plotWidth {
                return (item, x0, x1, x1 + 6 + text / 2, false, Double(x0) ... Double(x1 + 6 + text))
            }
            return (item, x0, x1, x0 - 6 - text / 2, false, Double(x0 - 6 - text) ... Double(x1))
        }
        let lanes = SpectrumLayout.lanes(items.map(\.5), gap: 8)
        return items.enumerated().map { index, item in
            Placed(ours: item.0, x0: item.1, x1: item.2, lane: lanes[index], labelX: item.3, inside: item.4)
        }
    }

    var body: some View {
        let plotWidth = max(width - Self.gutter, 100)
        let placed = placed(plotWidth: plotWidth)
        let laneCount = max(placed.map(\.lane).max().map { $0 + 1 } ?? 0, 1)
        let height = Self.landscapeHeight + Self.axisHeight + CGFloat(laneCount) * Self.laneHeight + 4
        let clashes = SpectrumLayout.clashes(ours.map { ($0.name, $0.span) })
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, _ in
                draw(in: &context, plotWidth: plotWidth, placed: placed)
            }
            .frame(height: height)
            .accessibilityLabel(accessibilityText)
            if ours.isEmpty {
                Text("None of our access points is on \(band.title).").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(clashes.enumerated()), id: \.offset) { _, pair in
                Label("\(pair.0) and \(pair.1) overlap: they share airtime. Move one to a channel of its own.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private func draw(in context: inout GraphicsContext, plotWidth: CGFloat, placed: [Placed]) {
        let domain = SpectrumLayout.domain(band)
        let left = Self.gutter
        let top: CGFloat = 14   // room for neighbour names
        let floor = Self.landscapeHeight
        func x(_ mhz: Double) -> CGFloat { left + CGFloat(SpectrumLayout.x(mhz, in: domain, width: Double(plotWidth))) }
        func y(dBm: Int) -> CGFloat { floor - (floor - top) * CGFloat(SpectrumLayout.loudness(dBm: dBm)) }

        // Signal guides, quiet so the hills read first.
        for dBm in [-50, -70, -90] {
            var line = Path()
            line.move(to: CGPoint(x: left, y: y(dBm: dBm)))
            line.addLine(to: CGPoint(x: left + plotWidth, y: y(dBm: dBm)))
            context.stroke(line, with: .color(.secondary.opacity(0.18)), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            context.draw(Text("\(dBm)").font(.system(size: 8).monospacedDigit()).foregroundStyle(.secondary),
                         at: CGPoint(x: left - 4, y: y(dBm: dBm)), anchor: .trailing)
        }

        // Our channels, shaded behind everything.
        for item in placed {
            let rect = CGRect(x: left + item.x0, y: top, width: max(item.x1 - item.x0, 2), height: floor - top)
            context.fill(Path(rect), with: .color(item.ours.colour.opacity(0.13)))
            var edge = Path()
            edge.move(to: CGPoint(x: rect.minX, y: rect.minY))
            edge.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            context.stroke(edge, with: .color(item.ours.colour.opacity(0.7)), lineWidth: 2)
        }

        // Neighbours: a hill each, quietest first so the loud ones sit on top.
        let heard = neighbours.prefix(80).compactMap { n -> (UniFiNeighbour, ChannelSpan, Int)? in
            guard let channel = n.channel, let dBm = n.dBm else { return nil }
            return (n, ChannelSpan.of(band: band, channel: channel, width: 20), dBm)
        }
        .sorted { $0.2 < $1.2 }
        for (_, span, dBm) in heard {
            let x0 = x(Double(span.low)), x1 = x(Double(span.high))
            let peak = y(dBm: dBm)
            let ramp = min(8, (x1 - x0) / 3)
            var hill = Path()
            hill.move(to: CGPoint(x: x0, y: floor))
            hill.addQuadCurve(to: CGPoint(x: x0 + ramp, y: peak), control: CGPoint(x: x0 + ramp * 0.2, y: peak))
            hill.addLine(to: CGPoint(x: x1 - ramp, y: peak))
            hill.addQuadCurve(to: CGPoint(x: x1, y: floor), control: CGPoint(x: x1 - ramp * 0.2, y: peak))
            let loud = SpectrumLayout.loudness(dBm: dBm)
            context.fill(hill, with: .color(.gray.opacity(0.08 + 0.17 * loud)))
            context.stroke(hill, with: .color(.gray.opacity(0.35 + 0.35 * loud)), lineWidth: 1)
        }

        // Names of the loudest neighbours, only where they fit.
        let named = heard.reversed().filter { ($0.0.essid ?? "").isEmpty == false }.prefix(8)
        let names = named.map { $0.0.essid! }
        let centres = named.map { Double(x(Double($0.1.low + $0.1.high) / 2) - left) }
        let widths = names.map { SpectrumLayout.textWidth($0, size: Double(Self.neighbourFont)) }
        let keep = SpectrumLayout.thinned(centres: centres, widths: widths, priority: named.map { $0.2 + 200 },
                                          gap: 6, limit: Double(plotWidth))
        for (index, entry) in named.enumerated() where keep.contains(index) {
            context.draw(Text(names[index]).font(.system(size: Self.neighbourFont)).foregroundStyle(.secondary),
                         at: CGPoint(x: left + CGFloat(centres[index]), y: y(dBm: entry.2) - 2), anchor: .bottom)
        }

        // Channel numbers, thinned to what fits.
        var baseline = Path()
        baseline.move(to: CGPoint(x: left, y: floor))
        baseline.addLine(to: CGPoint(x: left + plotWidth, y: floor))
        context.stroke(baseline, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
        let channels = SpectrumLayout.axisChannels(band)
        let axisCentres = channels.map { Double(x(Double(band.frequency(channel: $0.channel))) - left) }
        let axisWidths = channels.map { SpectrumLayout.textWidth("\($0.channel)", size: Double(Self.axisFont)) }
        let shown = SpectrumLayout.thinned(centres: axisCentres, widths: axisWidths, priority: channels.map(\.priority),
                                           gap: 6, limit: Double(plotWidth))
        for (index, entry) in channels.enumerated() {
            let tickX = left + CGFloat(axisCentres[index])
            var tick = Path()
            tick.move(to: CGPoint(x: tickX, y: floor))
            tick.addLine(to: CGPoint(x: tickX, y: floor + (shown.contains(index) ? 4 : 2)))
            context.stroke(tick, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
            if shown.contains(index) {
                context.draw(Text("\(entry.channel)").font(.system(size: Self.axisFont, weight: entry.priority == 2 ? .semibold : .regular).monospacedDigit())
                                .foregroundStyle(.secondary),
                             at: CGPoint(x: tickX, y: floor + 5), anchor: .top)
            }
        }

        // Our radios, one lane each where they'd collide.
        let lanesTop = floor + Self.axisHeight
        for item in placed {
            let laneY = lanesTop + CGFloat(item.lane) * Self.laneHeight
            let bar = CGRect(x: left + item.x0, y: laneY + 3, width: max(item.x1 - item.x0, 4), height: Self.laneHeight - 6)
            context.fill(Path(roundedRect: bar, cornerRadius: 6), with: .color(item.ours.colour.opacity(0.85)))
            let label = Text(item.ours.label).font(.system(size: Self.laneFont, weight: .semibold))
            if item.inside {
                context.draw(label.foregroundStyle(.white), at: CGPoint(x: left + item.labelX, y: bar.midY), anchor: .center)
            } else {
                context.draw(label.foregroundStyle(item.ours.colour), at: CGPoint(x: left + item.labelX, y: bar.midY), anchor: .center)
            }
        }
    }

    private var accessibilityText: String {
        let mine = ours.map(\.label).joined(separator: ", ")
        return "\(band.title): \(mine.isEmpty ? "none of our access points" : mine). \(neighbours.count) neighbouring networks."
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
