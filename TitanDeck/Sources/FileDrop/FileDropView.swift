// FileDrop/FileDropView.swift
import PhotosUI
import QuickLook
import QuickLookThumbnailing
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// AirDrop-style sending to the Titan PC: the PC in the middle, pulsing while
/// it's reachable; tap it to send. Files come from Photos, Files, drag and
/// drop, or any app's share sheet ("Open in TitanDeck"). Goes through
/// TitanDeck Host when it's paired, which also brings files back (From PC).
struct FileDropView: View {
    @ObservedObject var store: FileDropStore
    @ObservedObject var hostStore: HostStore
    let host: String
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var importingFiles = false
    @State private var showingSetup = false
    @State private var showingPairing = false
    @State private var dropTargeted = false
    @State private var previewURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    pcTarget
                        .padding(.top, 24)
                    if !hostStore.isPaired && !store.hasFolder {
                        setupPrompt
                    }
                    if let error = store.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    queue
                    addButtons
                    fromPC
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background {
                RoundedRectangle(cornerRadius: 0)
                    .fill(dropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
                    .ignoresSafeArea()
            }
            .dropDestination(for: IncomingFile.self) { files, _ in
                store.add(files.map(\.url))
                return !files.isEmpty
            } isTargeted: { dropTargeted = $0 }
            .navigationTitle("Send to PC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Setup", systemImage: "gearshape") { showingSetup = true }
                }
            }
            .sheet(isPresented: $showingSetup) {
                FileDropSetupView(store: store, host: host)
            }
            .sheet(isPresented: $showingPairing) {
                HostPairingView(host: hostStore, suggestedAddress: host)
            }
            .quickLookPreview($previewURL)
            .fileImporter(isPresented: $importingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { store.add(urls) }
            }
            .onChange(of: photoSelection) { _, selection in
                guard !selection.isEmpty else { return }
                Task {
                    for item in selection {
                        if let file = try? await item.loadTransferable(type: IncomingFile.self) {
                            store.add([file.url])
                        }
                    }
                    photoSelection = []
                }
            }
            .task(id: host) {
                while !Task.isCancelled {
                    if hostStore.isPaired { await hostStore.refresh() }
                    // The shared folder is the fallback, so only check it when the Host isn't answering.
                    if store.hasFolder && !hostStore.isOnline { await store.checkReachability(host: host) }
                    try? await Task.sleep(for: .seconds(4))
                }
            }
        }
    }

    // MARK: - The PC

    private var canSend: Bool { (hostStore.isOnline || store.hasFolder) && store.waitingCount > 0 && !store.isSending }

    private var isReachable: Bool { hostStore.isOnline || (store.hasFolder && store.reachability == .reachable) }

    private func sendAll() {
        Task { await store.send(via: hostStore.isOnline ? hostStore.client : nil) }
    }

    private var pcTarget: some View {
        VStack(spacing: 14) {
            Button {
                sendAll()
            } label: {
                ZStack {
                    if isReachable && !store.isSending {
                        PulseRings()
                    }
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 128, height: 128)
                        .shadow(color: .blue.opacity(0.4), radius: 18, y: 8)
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: store.items.filter { if case .sent = $0.state { return true }; return false }.count)
                    if store.isSending || store.overallProgress > 0 && store.overallProgress < 1 {
                        Circle()
                            .trim(from: 0, to: store.overallProgress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 144, height: 144)
                            .animation(.linear(duration: 0.2), value: store.overallProgress)
                    }
                }
                .frame(width: 220, height: 220)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send \(store.waitingCount) file\(store.waitingCount == 1 ? "" : "s") to the Titan PC")

            VStack(spacing: 4) {
                Text(hostStore.isPaired ? hostStore.displayName : "Titan PC")
                    .font(.title2.weight(.semibold))
                Text(routeDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                statusCapsule
            }
        }
    }

    private var statusCapsule: some View {
        let (text, colour): (String, Color) = {
            if store.isSending { return ("Sending...", .blue) }
            if hostStore.isOnline {
                return (store.waitingCount > 0 ? "Tap to send \(store.waitingCount)" : "Ready", .green)
            }
            if hostStore.isPaired && !store.hasFolder {
                if hostStore.connection == .checking { return ("Looking for the PC...", Color.secondary) }
                return ("TitanDeck Host not answering", Color.red)
            }
            if !store.hasFolder { return ("Not set up", .orange) }
            switch store.reachability {
            case .reachable: return (store.waitingCount > 0 ? "Tap to send \(store.waitingCount)" : "Ready", .green)
            case .unreachable: return ("PC not reachable", .red)
            case .checking: return ("Looking for the PC...", .secondary)
            case .unknown: return (host.isEmpty ? "No PC address set" : "Ready to try", .secondary)
            }
        }()
        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(colour.opacity(0.18), in: .capsule)
            .foregroundStyle(colour)
            .padding(.top, 4)
            .contentTransition(.opacity)
            .animation(.snappy, value: text)
    }

    /// "TitanDeck Host · 192.168.0.147", or the folder route when that's in use.
    private var routeDescription: String {
        if hostStore.isOnline || (hostStore.isPaired && !store.hasFolder) {
            return ["TitanDeck Host", hostStore.address].joined(separator: " · ")
        }
        let folder = hostStore.isPaired ? store.folderName.map { "\($0) (Host not answering)" } : store.folderName
        return [host.isEmpty ? nil : host, folder].compactMap { $0 }.joined(separator: " · ")
    }

    private var setupPrompt: some View {
        VStack(spacing: 12) {
            Text("Pair with TitanDeck Host on the PC to send files both ways, or use a Windows shared folder.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Pair with the PC", systemImage: "link") { showingPairing = true }
                    .buttonStyle(.glassProminent)
                Button("Shared Folder", systemImage: "folder.badge.plus") { showingSetup = true }
                    .buttonStyle(.glass)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - Files

    @ViewBuilder
    private var queue: some View {
        if store.items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("Add files below, drag them here, or use Share > TitanDeck in any app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(store.items) { item in
                    FileDropRow(item: item) { store.remove(item) }
                    if item.id != store.items.last?.id { Divider().padding(.leading, 64) }
                }
                if store.items.contains(where: { if case .sent = $0.state { return true }; return false }) {
                    Divider()
                    Button("Clear Sent", systemImage: "checkmark.circle") { withAnimation { store.clearSent() } }
                        .font(.callout)
                        .padding(.vertical, 10)
                }
            }
            .padding(.vertical, 4)
            .background(.fill.quinary, in: .rect(cornerRadius: 18))
            .animation(.snappy, value: store.items)
        }
    }

    private var addButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoSelection, maxSelectionCount: 50, matching: nil) {
                Label("Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            Button {
                importingFiles = true
            } label: {
                Label("Files", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

extension FileDropView {
    /// Files coming the other way: waiting in the PC's To iPad folder, and
    /// ones already here (Documents/From PC), with Quick Look and Share.
    @ViewBuilder
    var fromPC: some View {
        if hostStore.isPaired && (!hostStore.outbox.isEmpty || !hostStore.received.isEmpty) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("From PC", systemImage: "arrow.down.circle")
                        .font(.headline)
                    Spacer()
                    if hostStore.outbox.count > 1 {
                        Button("Get All") { Task { await hostStore.downloadAll() } }
                            .font(.callout.weight(.semibold))
                            .disabled(!hostStore.downloading.isEmpty || !hostStore.isOnline)
                    }
                }
                .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(hostStore.outbox) { entry in
                        FromPCWaitingRow(entry: entry, progress: hostStore.downloading[entry.name],
                                         enabled: hostStore.isOnline) {
                            Task { await hostStore.download(entry) }
                        }
                        Divider().padding(.leading, 64)
                    }
                    ForEach(hostStore.received.prefix(20)) { file in
                        FromPCReceivedRow(file: file) { previewURL = file.url }
                            .contextMenu {
                                ShareLink(item: file.url)
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    withAnimation { hostStore.deleteReceived(file) }
                                }
                            }
                        if file.id != hostStore.received.prefix(20).last?.id { Divider().padding(.leading, 64) }
                    }
                }
                .padding(.vertical, 4)
                .background(.fill.quinary, in: .rect(cornerRadius: 18))
                .animation(.snappy, value: hostStore.outbox)
                .animation(.snappy, value: hostStore.received)

                if hostStore.outbox.isEmpty {
                    Text("Put files in Public Documents\\TitanDeck\\To iPad on the PC to see them here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

private struct FromPCWaitingRow: View {
    let entry: HostFileEntry
    let progress: Double?
    let enabled: Bool
    let download: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let progress {
                    ProgressView(value: progress)
                } else {
                    Text("\(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)) · waiting on the PC")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if progress == nil {
                Button("Get", action: download)
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(!enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct FromPCReceivedRow: View {
    let file: HostStore.Received
    let open: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    Group {
                        if let thumbnail {
                            Image(uiImage: thumbnail).resizable().scaledToFill()
                        } else {
                            Image(systemName: "doc.fill").font(.title2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(.rect(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)) · \(file.date.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            ShareLink(item: file.url) {
                Image(systemName: "square.and.arrow.up").font(.title3)
            }
            .accessibilityLabel("Share \(file.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task(id: file.url) {
            let request = QLThumbnailGenerator.Request(fileAt: file.url, size: CGSize(width: 80, height: 80),
                                                       scale: 2, representationTypes: .thumbnail)
            thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).uiImage
        }
    }
}

/// One queued file: thumbnail, name, size and how it's going.
private struct FileDropRow: View {
    let item: FileDropStore.Item
    let remove: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                } else {
                    Image(systemName: "doc.fill").font(.title2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                switch item.state {
                case .waiting:
                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                case .sending:
                    ProgressView(value: item.progress)
                case .sent(let name):
                    Text(name == item.name ? "Sent" : "Sent as \(name)")
                        .font(.caption).foregroundStyle(.green)
                case .failed(let message):
                    Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            switch item.state {
            case .sent:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
                    .transition(.scale.combined(with: .opacity))
            case .sending:
                EmptyView()
            default:
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.name)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task(id: item.url) {
            let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: 80, height: 80),
                                                       scale: 2, representationTypes: .thumbnail)
            thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).uiImage
        }
    }
}

/// Expanding rings behind the PC while it's reachable, like AirDrop's radar.
private struct PulseRings: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0 ..< 3) { ring in
                Circle()
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                    .frame(width: 128, height: 128)
                    .scaleEffect(animate ? 1.7 : 1)
                    .opacity(animate ? 0 : 0.8)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(ring) * 0.8),
                               value: animate)
            }
        }
        .onAppear { animate = true }
        .accessibilityHidden(true)
    }
}

/// A file handed over by Photos or drag and drop, copied somewhere we can read.
struct IncomingFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FileDropIncoming", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent("\(UUID().uuidString)-\(received.file.lastPathComponent)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return IncomingFile(url: destination)
        }
    }
}
