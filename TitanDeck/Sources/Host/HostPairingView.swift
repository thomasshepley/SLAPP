// Host/HostPairingView.swift
import SwiftUI
import UIKit

/// Pair with TitanDeck Host: pick the PC (found over Bonjour, or typed in),
/// then type the 6-digit code its window shows.
struct HostPairingView: View {
    @ObservedObject var host: HostStore
    /// The PC address already in Settings (remote desktop or Titan). Typed or
    /// discovered addresses lose any "%en0" interface ending before use.
    let suggestedAddress: String
    @StateObject private var discovery = HostDiscovery()
    @State private var address = ""
    @State private var code = ""
    @State private var selected: String?
    @State private var resolving: String?
    @State private var isPairing = false
    @State private var error: String?
    @FocusState private var codeFocused: Bool
    @Environment(\.dismiss) private var dismiss

    static let downloadPage = URL(string: "https://github.com/thomasshepley/SLAPP/releases")!

    private var canPair: Bool {
        !address.trimmingCharacters(in: .whitespaces).isEmpty && code.count == 6 && !isPairing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Install TitanDeck Host on the PC")
                                .font(.headline)
                            Text("Get TitanDeckHost-Setup from the newest host-v release on GitHub, run it on the Titan PC, then press Show a pairing code in its window.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "desktopcomputer.and.arrow.down")
                            .foregroundStyle(.blue)
                    }
                    ShareLink(item: Self.downloadPage) {
                        Label("Share the Download Link", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    if discovery.found.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking for TitanDeck Host...")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(discovery.found) { found in
                        Button {
                            choose(found)
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(found.name).foregroundStyle(.primary)
                                        if let version = found.version {
                                            Text("TitanDeck Host \(version)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: "desktopcomputer")
                                }
                                Spacer()
                                if resolving == found.name {
                                    ProgressView()
                                } else if selected == found.name {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                    LabeledContent("Address") {
                        TextField("e.g. 192.168.1.20", text: $address)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .onChange(of: address) { _, _ in
                                if resolving == nil { selected = nil }
                            }
                    }
                } header: {
                    Text("PC")
                } footer: {
                    Text("PCs running TitanDeck Host show up here. If yours doesn't, type its address - the same one as for Remote Desktop.")
                }

                Section {
                    TextField("000 000", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .focused($codeFocused)
                        .onChange(of: code) { _, newValue in
                            let digits = HostAPI.normaliseCode(newValue)
                            if digits != newValue { code = digits }
                        }
                } header: {
                    Text("Pairing code")
                } footer: {
                    Text("Shown in TitanDeck Host on the PC. Each code works once, for 5 minutes.")
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Button {
                        Task { await pair() }
                    } label: {
                        HStack {
                            Spacer()
                            if isPairing { ProgressView().padding(.trailing, 6) }
                            Text(isPairing ? "Pairing..." : "Pair").font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!canPair)
                }
            }
            .navigationTitle("Pair with the PC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .onAppear {
                if address.isEmpty { address = host.address.isEmpty ? suggestedAddress : host.address }
                discovery.start()
            }
            .onDisappear { discovery.stop() }
            .onChange(of: discovery.found) { _, found in
                // One PC on the network and nothing chosen yet: that's the one.
                if found.count == 1, selected == nil, resolving == nil, let only = found.first,
                   address.isEmpty || address == suggestedAddress {
                    choose(only)
                }
            }
        }
    }

    private func choose(_ found: HostDiscovery.Found) {
        resolving = found.name
        error = nil
        Task {
            let resolved = await HostDiscovery.address(of: found)
            resolving = nil
            if let resolved {
                address = resolved
                selected = found.name
                codeFocused = true
            } else {
                error = "Found \(found.name) but couldn't connect to it. Try typing its address."
            }
        }
    }

    private func pair() async {
        isPairing = true
        error = nil
        defer { isPairing = false }
        do {
            try await host.pair(address: address, code: code)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self.error = error.localizedDescription
            code = ""
        }
    }
}
