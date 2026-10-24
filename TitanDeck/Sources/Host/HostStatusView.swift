// Host/HostStatusView.swift
import SwiftUI

/// The PC's health as TitanDeck Host sees it: Remote Desktop checks with the
/// fixes the iPad is allowed to press, PC details, and unpairing.
struct HostStatusView: View {
    @ObservedObject var host: HostStore
    @State private var confirmForget = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    HostConnectionBadge(host: host, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(headline).font(.title3.weight(.semibold))
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                if let message = host.lastMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let status = host.status {
                Section("Checks") {
                    ForEach(status.checks) { check in
                        HostCheckRow(check: check, isFixing: host.fixing == check.id, isBusy: host.fixing != nil) {
                            Task { await host.fix(check) }
                        }
                    }
                }

                Section {
                    Button {
                        Task { await host.sendNewestRdpWrapIni() }
                    } label: {
                        HStack {
                            Label("Send Newest rdpwrap.ini", systemImage: "arrow.down.doc")
                            Spacer()
                            if host.fixing == "rdpwrap-ini" { ProgressView() }
                        }
                    }
                    .disabled(host.fixing != nil || !host.isOnline)
                } header: {
                    Text("Remote Desktop after a Windows update")
                } footer: {
                    Text("If the PC has no internet, this downloads the newest RDP Wrapper ini on the iPad, hands it to the PC and applies it. Only needed on Windows Home.")
                }

                Section("PC") {
                    LabeledContent("Windows", value: status.windowsVersion)
                    LabeledContent("Edition", value: status.edition)
                    LabeledContent("Remote Desktop build", value: status.termsrvVersion)
                    LabeledContent("Titan") {
                        Text(status.titanRunning ? "Running" : "Not running")
                            .foregroundStyle(status.titanRunning ? .green : .secondary)
                    }
                    LabeledContent("TitanDeck Host", value: status.hostVersion)
                    LabeledContent("Address", value: host.address)
                }
            } else if host.isOnline {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Asking the PC...").foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Unpair This Device", systemImage: "minus.circle", role: .destructive) { confirmForget = true }
            } footer: {
                Text("You can also remove devices in TitanDeck Host on the PC.")
            }
        }
        .navigationTitle(host.displayName)
        .refreshable { await host.refresh(full: true) }
        .task {
            await host.refresh(full: true)
            await host.keepRefreshing(every: .seconds(5))
        }
        .confirmationDialog("Unpair from \(host.displayName)?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Unpair", role: .destructive) {
                host.forget()
                dismiss()
            }
        } message: {
            Text("Sending files and fixes through the Host stop until you pair again.")
        }
        .animation(.snappy, value: host.status)
    }

    private var headline: String {
        switch host.connection {
        case .online:
            switch host.status?.overall {
            case .ok?: "Ready for TitanDeck"
            case .warning?: "Working - a couple of things to look at"
            case .problem?: "Needs attention"
            case nil: "Connected"
            }
        case .checking: "Checking..."
        case .offline: "Not answering"
        case .notPaired: "Not paired"
        }
    }

    private var subtitle: String {
        switch host.connection {
        case .online(let hello): "\(hello.machineName) · Host \(hello.hostVersion)"
        case .offline(let reason): reason
        case .checking: host.address
        case .notPaired: "Pair from Settings"
        }
    }
}

private struct HostCheckRow: View {
    let check: HostCheck
    let isFixing: Bool
    let isBusy: Bool
    let fix: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(colour)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title).font(.callout.weight(.semibold))
                Text(check.detail).font(.caption).foregroundStyle(.secondary)
                if check.fix != nil && !check.canFixFromIPad {
                    Label("\(check.fixTitle ?? "Fix") on the PC", systemImage: "desktopcomputer")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            if check.canFixFromIPad {
                if isFixing {
                    ProgressView()
                } else {
                    Button(check.fixTitle ?? "Fix", action: fix)
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                        .disabled(isBusy)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var symbol: String {
        switch check.state {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .problem: "xmark.octagon.fill"
        }
    }

    private var colour: Color {
        switch check.state {
        case .ok: Color.green
        case .warning: Color.orange
        case .problem: Color.red
        }
    }
}

/// A PC symbol with a coloured status dot, for Settings and the Send sheet.
struct HostConnectionBadge: View {
    @ObservedObject var host: HostStore
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "desktopcomputer")
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.blue.gradient, in: .rect(cornerRadius: size * 0.26))
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(dotColour)
                    .frame(width: size * 0.32, height: size * 0.32)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: size * 0.08, y: size * 0.08)
            }
            .accessibilityHidden(true)
    }

    private var dotColour: Color {
        switch host.connection {
        case .online:
            switch host.status?.overall {
            case .warning?: Color.orange
            case .problem?: Color.red
            default: Color.green
            }
        case .checking: Color.gray
        case .offline: Color.red
        case .notPaired: Color.gray
        }
    }
}
