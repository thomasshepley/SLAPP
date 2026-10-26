// Host/ChangeHostAddressView.swift
import SwiftUI

/// Moves the paired Host to a new address without pairing again: type it,
/// or pick the PC from the ones found on the network (Hosts that have a
/// network adapter picked announce that adapter's address).
struct ChangeHostAddressView: View {
    @ObservedObject var host: HostStore
    @StateObject private var discovery = HostDiscovery()
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var resolving: String?
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("PC address", text: $address)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Address")
                } footer: {
                    Text("Now: \(host.address)")
                }

                Section("On this network") {
                    if discovery.found.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking for TitanDeck Host...").foregroundStyle(.secondary)
                        }
                    }
                    ForEach(discovery.found) { found in
                        Button {
                            pick(found)
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(found.name).foregroundStyle(.primary)
                                        if let announced = found.address {
                                            Text(announced).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: "desktopcomputer")
                                }
                                Spacer()
                                if resolving == found.name { ProgressView() }
                            }
                        }
                    }
                }

                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }
            }
            .navigationTitle("Change Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Use") { Task { await save() } }
                            .disabled(HostAPI.cleanAddress(address).isEmpty)
                    }
                }
            }
            .onAppear {
                address = host.address
                discovery.start()
            }
            .onDisappear { discovery.stop() }
        }
    }

    private func pick(_ found: HostDiscovery.Found) {
        resolving = found.name
        error = nil
        Task {
            let resolved = await HostDiscovery.address(of: found)
            resolving = nil
            if let resolved {
                address = resolved
            } else {
                error = "Found \(found.name) but couldn't connect to it. Try typing its address."
            }
        }
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            try await host.changeAddress(to: address)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
