// Remote/RDPQualityView.swift
import SwiftUI

/// Picture quality for the remote desktop: three presets for the conditions
/// on set, and the individual settings underneath. Applying reconnects.
struct RDPQualityView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var host: HostStore
    @State private var draft = RDPQuality.preset(.best)
    @State private var isApplying = false
    @State private var message: String?

    private var saved: RDPQuality { appState.rdpSettings.quality }
    private var pcNow: RDPQuality.PCSettings? { host.pcQuality.flatMap(RDPQuality.pcSettings(from:)) }
    /// Something to apply: the iPad's half changed, or the PC doesn't match yet.
    private var hasChanges: Bool { draft != saved || (host.isOnline && pcNow != nil && pcNow != draft.pcSettings) }

    var body: some View {
        Form {
            Section {
                ForEach(RDPQuality.Preset.allCases) { preset in
                    Button {
                        withAnimation(.snappy) { draft = .preset(preset) }
                    } label: {
                        PresetRow(preset: preset, isSelected: draft.preset == preset)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Preset")
            } footer: {
                Text(draft.preset == nil ? "Custom: \(draft.summary)." : "\(draft.preset?.title ?? ""): \(draft.summary).")
            }

            Section {
                Picker("Windows effects", selection: $draft.visuals) {
                    ForEach(RDPQuality.Visuals.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("On this iPad")
            } footer: {
                Text("Wallpaper, animations and smooth fonts all cost bandwidth. Plain Windows stays quickest on a poor link.")
            }

            Section {
                Picker("Image quality", selection: $draft.pcImageQuality) {
                    ForEach(RDPQuality.PCImageQuality.allCases) { Text($0.title).tag($0) }
                }
                Picker("Graphics mode", selection: $draft.pcProfile) {
                    ForEach(RDPQuality.PCProfile.allCases) { Text($0.title).tag($0) }
                }
                Picker("Frame rate", selection: $draft.pcFrameRate) {
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }
                .pickerStyle(.segmented)
                pcStatusRow
            } header: {
                Text("On the PC")
            } footer: {
                Text("Set through TitanDeck Host. Lossless and 60 fps look best but need a strong link; lowest bandwidth trades sharpness for staying responsive.")
            }
            .disabled(!host.isPaired)

            Section {
                Button {
                    Task { await apply() }
                } label: {
                    HStack {
                        Spacer()
                        if isApplying { ProgressView().padding(.trailing, 6) }
                        Text(appState.rdp.state == .connected ? "Apply and Reconnect" : "Apply").font(.headline)
                        Spacer()
                    }
                }
                .disabled(isApplying || !hasChanges)
                if let message {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Picture Quality")
        .onAppear { draft = saved }
        .task { if host.isPaired { await host.refresh(full: true) } }
    }

    @ViewBuilder
    private var pcStatusRow: some View {
        if !host.isPaired {
            Label("Pair TitanDeck Host (Settings) to change these.", systemImage: "link")
                .font(.callout).foregroundStyle(.secondary)
        } else if !host.isOnline {
            Label("The PC's Host isn't answering.", systemImage: "wifi.exclamationmark")
                .font(.callout).foregroundStyle(.orange)
        } else if let pcNow {
            let matches = pcNow == draft.pcSettings
            Label(matches ? "The PC is set to this." : "The PC is on \(pcNow.imageQuality.title.lowercased()) quality, \(pcNow.frameRate) fps.",
                  systemImage: matches ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                .font(.callout)
                .foregroundStyle(matches ? Color.green : Color.secondary)
        } else {
            Label("Update TitanDeck Host on the PC to 0.2 to change these.", systemImage: "arrow.down.circle")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func apply() async {
        isApplying = true
        message = await appState.applyRemoteQuality(draft)
        isApplying = false
    }
}

private struct PresetRow: View {
    let preset: RDPQuality.Preset
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: preset.symbol)
                .font(.title2)
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: 46, height: 46)
                .background(isSelected ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.accentColor.opacity(0.12)),
                            in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.title).font(.headline)
                Text(preset.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
