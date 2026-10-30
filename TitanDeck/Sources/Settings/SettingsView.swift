// Settings/SettingsView.swift
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import StreamDeckSimulator

/// M3 settings: Titan host, connection test, test fire buttons and a latency
/// log. The deck editor (DeckEditorView / KeyInspectorView) arrives in M4.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingWhatsNew = false
    /// Show mode hides the test tools (Settings > Mode).
    @AppStorage(SettingsKeys.showMode) private var showMode = false

    var body: some View {
        NavigationStack {
            Form {
                ModeSection(intensity: appState.intensity)
                connectionSection
                RemoteDesktopSection(session: appState.rdp)
                HostSection(host: appState.host)
                DeskLinkSection(desk: appState.deskLink, intensity: appState.intensity, host: appState.host)
                SharedUserSection()
                FileDropSection(store: appState.fileDrop, host: appState.host)
                if !showMode { testSection }
                DeckSection(deck: appState.deck)
                GroupSetsSection()
                if !showMode { SoakLogSection(store: appState.connectionLog) }
                WatchSection(watch: appState.watch)
                if !showMode { logSection }
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    private var connectionSection: some View {
        Section {
            if appState.localNetwork.status == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Label(LocalNetworkHelp.message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Open iPad Settings") { LocalNetworkHelp.openSettings() }
                }
            }
            LabeledContent("Titan PC address") {
                TextField("e.g. 192.168.1.20", text: $appState.titanHost)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 260)
            }
            Toggle("Through TitanDeck Host", isOn: $appState.titanViaHost)
            HStack {
                Button("Test connection") { appState.checkConnection() }
                    .disabled(appState.titanHost.isEmpty || appState.isCheckingConnection)
                Spacer()
                if appState.isCheckingConnection {
                    ProgressView()
                } else if let version = appState.titanVersion {
                    Label("Titan \(version)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("Connection")
        } footer: {
            Text(appState.titanViaHost
                 ? "Titan's WebAPI through TitanDeck Host (0.9+, port \(TitanEndpoints.viaHostPort)), so the Host's Titan log shows every call and what Titan answered. If the Host doesn't answer, calls go straight to Titan."
                 : "WebAPI on port \(TitanEndpoints.defaultPort). Turn on Through TitanDeck Host to see every call in the Host's Titan log.")
        }
    }

    private var testSection: some View {
        Section("Test") {
            Button("Fire test playback 1") { appState.fire(.playbackGo(userNumber: 1)) }
            Button("Release playback 1") { appState.fire(.playbackRelease(userNumber: 1)) }
        }
        .disabled(appState.titanHost.isEmpty)
    }

    private var logSection: some View {
        Section("Recent calls") {
            if appState.recentResults.isEmpty {
                Text("Nothing sent yet").foregroundStyle(.secondary)
            }
            ForEach(Array(appState.recentResults.enumerated()), id: \.offset) { _, result in
                HStack {
                    Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(result.ok ? .green : .red)
                    Text(result.action.summary)
                    Spacer()
                    Text(result.ok ? "\(result.milliseconds) ms" : (result.error ?? "HTTP \(result.statusCode ?? 0)"))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.versionString)
            Button("What's New", systemImage: "sparkles") { showingWhatsNew = true }
        }
        .sheet(isPresented: $showingWhatsNew) { WhatsNewView() }
    }
}

/// M7: the soak-test log - drop-out totals per link, recent events, export.
private struct SoakLogSection: View {
    @ObservedObject var store: ConnectionLogStore
    @State private var confirmClear = false

    var body: some View {
        Section {
            let summaries = store.log.summaries()
            if summaries.isEmpty {
                Text("Nothing logged yet").foregroundStyle(.secondary)
            }
            ForEach(summaries, id: \.source) { summary in
                LabeledContent(summary.source.rawValue) {
                    Text(describe(summary))
                        .foregroundStyle(summary.stillDown ? .red : (summary.dropouts == 0 ? .green : .orange))
                        .multilineTextAlignment(.trailing)
                }
            }
            DisclosureGroup("Recent events (\(store.log.events.count))") {
                ForEach(store.log.events.suffix(30).reversed()) { event in
                    HStack(alignment: .firstTextBaseline) {
                        Text(event.date, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: icon(for: event.status))
                            .foregroundStyle(color(for: event.status))
                        Text("\(event.source.rawValue): \(event.detail)")
                            .font(.callout)
                    }
                }
            }
            ShareLink(item: store.export, preview: SharePreview("TitanDeck connection log")) {
                Label("Export log as CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(store.log.events.isEmpty)
            Button("Clear log", role: .destructive) { confirmClear = true }
                .disabled(store.log.events.isEmpty)
                .confirmationDialog("Clear the connection log?", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Clear", role: .destructive) { store.clear() }
                } message: {
                    Text("Export it first if you need it - this can't be undone.")
                }
        } header: {
            Text("Soak test log")
        } footer: {
            Text("Every drop-out and recovery is logged, even while this screen is closed. For the 8-hour soak test: clear the log at the start, then export it at the end.")
        }
    }

    private func describe(_ summary: OutageSummary) -> String {
        if summary.dropouts == 0 { return "No drop-outs" }
        let plural = summary.dropouts == 1 ? "drop-out" : "drop-outs"
        var text = "\(summary.dropouts) \(plural), longest \(Self.duration(summary.longestOutage)), total \(Self.duration(summary.totalDowntime))"
        if summary.stillDown { text += " - down now" }
        return text
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : (seconds >= 60 ? [.minute, .second] : [.second])
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(seconds, 0).rounded()) ?? "\(Int(seconds)) s"
    }

    private func icon(for status: ConnectionEvent.Status) -> String {
        switch status {
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill"
        case .info: return "info.circle"
        }
    }

    private func color(for status: ConnectionEvent.Status) -> Color {
        switch status {
        case .up: return .green
        case .down: return .red
        case .info: return .secondary
        }
    }
}

/// TitanDeck Host on the PC (M18): pair, then PC health and fixes.
private struct HostSection: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var host: HostStore
    @State private var showingPairing = false

    var body: some View {
        Section {
            if host.isPaired {
                NavigationLink {
                    HostStatusView(host: host, titanHost: $appState.titanHost, rdpSettings: $appState.rdpSettings)
                } label: {
                    HStack(spacing: 12) {
                        HostConnectionBadge(host: host)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.displayName)
                            Text(summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Button("Pair with TitanDeck Host", systemImage: "link") { showingPairing = true }
            }
        } header: {
            Text("TitanDeck Host")
        } footer: {
            Text("The Windows app for the Titan PC: keeps Remote Desktop working, fixes it from here, and moves files both ways. Get it from the host-v releases on GitHub.")
        }
        // In a Form, a Section's modifiers land on its rows. Pairing swaps the
        // Pair row for the status row, which would open this sheet again, so
        // it only shows while not paired.
        .sheet(isPresented: Binding(get: { showingPairing && !host.isPaired }, set: { showingPairing = $0 })) {
            HostPairingView(host: host, suggestedAddress: appState.pcHost)
        }
        .task(id: host.isPaired) {
            if host.isPaired {
                showingPairing = false
                await host.refresh()
            }
        }
    }

    private var summary: String {
        switch host.connection {
        case .online:
            switch host.status?.overall {
            case .ok?: "Ready"
            case .warning?: "Working, a couple of things to look at"
            case .problem?: "Needs attention"
            case nil: "Connected"
            }
        case .checking: "Checking..."
        case .offline: "Not answering"
        case .notPaired: "Not paired"
        }
    }
}

/// Sending files to the PC (M16): through the Host, or the shared folder.
private struct FileDropSection: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var store: FileDropStore
    @ObservedObject var host: HostStore

    var body: some View {
        Section {
            Button {
                appState.showingFileDrop = true
            } label: {
                LabeledContent {
                    Text(route)
                } label: {
                    Label("Send Files to PC", systemImage: "paperplane.fill")
                }
            }
        } header: {
            Text("File drop")
        } footer: {
            Text("Sends photos and files to the PC, through TitanDeck Host when it's paired, otherwise into a shared folder. You can also share to TitanDeck from any app.")
        }
    }

    private var route: String {
        switch (host.isPaired, store.folderName) {
        case (true, nil): "TitanDeck Host"
        case (true, let folder?): "Host, then \(folder)"
        case (false, let folder?): folder
        case (false, nil): "Not set up"
        }
    }
}

private struct RemoteDesktopSection: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: RDPSession
    @State private var password = ""
    @State private var confirmForget = false
    @AppStorage(SettingsKeys.remoteDesktopEnabled)
    private var remoteDesktopEnabled = UIDevice.current.userInterfaceIdiom != .phone

    var body: some View {
        Section {
            Toggle("Show the Remote tab", isOn: $remoteDesktopEnabled)
            LabeledContent("PC address") {
                TextField(appState.titanHost.isEmpty ? "e.g. 192.168.1.20" : "Same as Titan (\(appState.titanHost))",
                          text: $appState.rdpSettings.host)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 300)
            }
            LabeledContent("Windows user") {
                TextField("Username", text: $appState.rdpSettings.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 300)
            }
            LabeledContent("Password") {
                SecureField("Saved in the Keychain", text: $password)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 300)
                    .onSubmit { appState.remotePassword = password }
            }
            LabeledContent("Domain") {
                TextField("Optional", text: $appState.rdpSettings.domain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 300)
            }
            Toggle("Connect when TitanDeck opens", isOn: $appState.rdpSettings.connectOnLaunch)
            Picker("Keyboard's Command key", selection: $appState.rdpSettings.commandKey) {
                ForEach(RDPKeyboard.CommandKey.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            NavigationLink {
                RDPQualityView(host: appState.host)
            } label: {
                LabeledContent {
                    Text(appState.rdpSettings.quality.preset?.title ?? "Custom")
                } label: {
                    Label("Picture quality", systemImage: "dial.medium")
                }
            }
            HStack {
                switch session.state {
                case .connected, .connecting:
                    Button("Disconnect", role: .destructive) { session.disconnect() }
                default:
                    Button("Connect") {
                        appState.remotePassword = password
                        appState.connectRemote()
                        appState.mode = .remote
                    }
                    .disabled(!appState.isRemoteConfigured)
                }
                Spacer()
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            Button("Forget saved PC certificates", role: .destructive) { confirmForget = true }
                .confirmationDialog("Forget the remembered certificates?", isPresented: $confirmForget,
                                    titleVisibility: .visible) {
                    Button("Forget", role: .destructive) { appState.forgetRemoteCertificates() }
                } message: {
                    Text("The next connection will trust whichever certificate the PC presents. Only do this if you know why it changed.")
                }
        } header: {
            Text("Remote desktop")
        } footer: {
            Text("The PC needs RDP enabled (RDP Wrapper on Windows Home) and TCP 3389 allowed through its firewall. Three-finger long press on the desktop opens Settings. A Magic Keyboard types on the PC while the remote desktop is showing; iPadOS keeps a few shortcuts for itself (Cmd-Tab, Cmd-Space, Globe keys).")
        }
        .onAppear { password = appState.remotePassword }
        .onDisappear { appState.remotePassword = password }
    }

    private var statusText: String {
        switch session.state {
        case .idle: return "Not connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected to \(session.host)"
        case .failed(let message): return message
        }
    }
}

private struct DeckSection: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var deck: DeckSessionController
    @AppStorage(SettingsKeys.showMode) private var showMode = false
    @State private var confirmReset = false
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        Section("Stream Deck") {
            LabeledContent("Driver", value: deck.statusText)
            if let device = deck.device {
                LabeledContent("Device", value: device.info.productName)
                LabeledContent("Keys", value: "\(device.capabilities.keyCount) (\(device.capabilities.keyColumns) x \(device.capabilities.keyRows))")
            } else {
                LabeledContent("Device", value: "None attached")
            }
            LabeledContent("Profile", value: "\(deck.profile.name) - \(deck.profile.pages.count) pages")
            NavigationLink {
                DeckEditorView(deck: deck)
            } label: {
                Label("Edit deck profile", systemImage: "square.grid.3x3.fill")
            }
            // Test mode, every build (TestFlight included): the deck can be tried without hardware.
            if !showMode {
                Button("Show virtual Stream Deck", systemImage: "rectangle.grid.2x2") {
                    StreamDeckSimulator.show(defaultStreamDeck: .regular)
                }
            }
            Picker("Deck mounted", selection: Binding(
                get: { deck.profile.orientation },
                set: { newValue in
                    var profile = deck.profile
                    profile.orientation = newValue
                    appState.updateProfile(profile)
                })) {
                ForEach(DeckOrientation.allCases) { Text($0.title).tag($0) }
            }
            LiveKeyStateRow(poller: appState.playbackState)
            NavigationLink {
                FlashFadeRulesView()
            } label: {
                LabeledContent {
                    Text(appState.flashFadeRules.isEmpty ? "None" : "\(appState.flashFadeRules.count)")
                } label: {
                    Label("Flash fades", systemImage: "light.max")
                }
            }
            ColorPicker(selection: Binding(
                get: { Color(uiColor: UIColor(hex: appState.heldKeyColour)) },
                set: { appState.heldKeyColour = HexColor(UIColor($0)).hexString }), supportsOpacity: false) {
                Label("Held key colour", systemImage: "hand.point.up.left.fill")
            }
            ShareLink(item: ProfileFile(profile: deck.profile), preview: SharePreview("TitanDeck profile: \(deck.profile.name)")) {
                Label("Export profile", systemImage: "square.and.arrow.up")
            }
            Button("Import profile...", systemImage: "square.and.arrow.down") { isImporting = true }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                    do {
                        try appState.importProfile(from: result.get())
                    } catch {
                        importError = error.localizedDescription
                    }
                }
                .alert("Couldn't import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(importError ?? "")
                }
            Button("Reset to default profile", role: .destructive) { confirmReset = true }
                .confirmationDialog("Replace the current deck profile with the default?",
                                    isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { appState.resetProfileToDefault() }
                }
        }
    }
}

/// M10: Apple Watch status. Hidden on devices with no paired Watch.
private struct WatchSection: View {
    @ObservedObject var watch: WatchBridge

    var body: some View {
        if watch.isPaired {
            Section {
                LabeledContent("Watch app", value: watch.isWatchAppInstalled ? "Installed" : "Not installed")
                if let last = watch.lastCommand {
                    LabeledContent("Last from Watch", value: last)
                }
            } header: {
                Text("Apple Watch")
            } footer: {
                Text("Install TitanDeck on the Watch from the Watch app on this iPhone. Turn the Digital Crown to pick a playback, then hold GO (or double tap) to fire. The Watch goes through this iPhone when it's nearby, or straight to Titan over Wi-Fi when it isn't.")
            }
        }
    }
}

/// M8: toggle for lighting keys of live playbacks, with whether Titan supports it.
private struct LiveKeyStateRow: View {
    @ObservedObject var poller: PlaybackStatePoller

    var body: some View {
        Toggle(isOn: $poller.isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Light keys for live playbacks")
                switch poller.support {
                case .unknown:
                    Text("Waiting for Titan").font(.caption).foregroundStyle(.secondary)
                case .working:
                    Text("Working").font(.caption).foregroundStyle(.green)
                case .noUserNumbers:
                    Text("This Titan version doesn't report playback user numbers, so keys can't be matched.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
}

private extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
