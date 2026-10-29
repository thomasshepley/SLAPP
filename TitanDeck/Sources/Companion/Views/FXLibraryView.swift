// Companion/Views/FXLibraryView.swift
import AVKit
import PhotosUI
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

/// Pixel-effect clips and bitmaps (fire, police, fireworks, lightning...) to
/// run through Prism / the pixel mapper. Add from Photos or Files, tag them,
/// and send them to the Titan PC with the file uploader. In the FX tab
/// (0.37); an effect with its Prism Folder and File is on the deck's FX page.
/// Sync with Prism (0.39) brings in the clips Prism has, which stay on the PC.
struct FXLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var store: FXLibraryStore
    @State private var search = ""
    @State private var category: FXItem.Category?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var choosingPhotos = false
    @State private var importing = false
    @State private var selecting = false
    @State private var chosen: Set<UUID> = []
    @State private var detail: FXItem?
    @State private var dropTargeted = false

    var body: some View {
        let groups = store.index.grouped(search: search, category: category)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                categoryChips
                if let message = store.lastMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
                ForEach(groups, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(group.category.rawValue, systemImage: group.category.symbol)
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                            ForEach(group.items) { item in
                                Button {
                                    if selecting { toggle(item) } else { detail = item }
                                } label: {
                                    FXCard(item: item, url: store.localURL(for: item), isChosen: selecting && chosen.contains(item.id))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if let url = store.localURL(for: item) {
                                        Button("Send to PC", systemImage: "paperplane") { send([item]) }
                                        ShareLink(item: url)
                                    }
                                    Button(item.isOnIPad ? "Delete" : "Remove from Library", systemImage: "trash", role: .destructive) {
                                        store.delete(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(dropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .overlay {
            if store.index.items.isEmpty {
                ContentUnavailableView {
                    Label("No effects yet", systemImage: "film.stack")
                } description: {
                    Text("Sync with Prism to bring in the clips Prism has, or add videos and bitmaps for pixel effects - fire, police lights, fireworks, lightning - and send them to the Titan PC.")
                } actions: {
                    Button("Sync with Prism", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await appState.syncPrism() }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(appState.syncingPrism)
                    addMenu.buttonStyle(.glass)
                }
            } else if groups.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Effect name or notes")
        .navigationTitle("FX Library")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if selecting {
                    Button("Send \(chosen.count)", systemImage: "paperplane.fill") {
                        send(store.index.items.filter { chosen.contains($0.id) })
                    }
                    .disabled(!store.index.items.contains { chosen.contains($0.id) && $0.isOnIPad })
                    Button("Done") {
                        selecting = false
                        chosen.removeAll()
                    }
                } else {
                    addMenu
                    if !store.index.items.isEmpty {
                        Button("Select", systemImage: "checkmark.circle") { selecting = true }
                    }
                }
            }
        }
        .dropDestination(for: IncomingFile.self) { files, _ in
            Task { await store.add(files.map(\.url)) }
            return !files.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .photosPicker(isPresented: $choosingPhotos, selection: $photoSelection, maxSelectionCount: 30,
                      matching: .any(of: [.videos, .images]))
        .fileImporter(isPresented: $importing, allowedContentTypes: [.movie, .video, .image, .gif],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { Task { await store.add(urls) } }
        }
        .onChange(of: photoSelection) { _, selection in
            guard !selection.isEmpty else { return }
            Task {
                var urls: [URL] = []
                for item in selection {
                    if let file = try? await item.loadTransferable(type: IncomingFile.self) { urls.append(file.url) }
                }
                await store.add(urls)
                photoSelection = []
            }
        }
        .sheet(item: $detail) { item in
            NavigationStack {
                FXDetailView(item: item, store: store) { send([$0]) }
            }
        }
    }

    private var addMenu: some View {
        Menu {
            // A PhotosPicker inside a Menu never appears (the menu takes its
            // sheet away as it closes), so the menu only flips a flag and the
            // picker hangs off the screen itself.
            Button("From Photos", systemImage: "photo.on.rectangle") { choosingPhotos = true }
            Button("From Files", systemImage: "folder") { importing = true }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip("All", symbol: "square.grid.2x2", isOn: category == nil) { category = nil }
                ForEach(FXItem.Category.allCases) { kind in
                    let count = store.index.items.filter { $0.category == kind }.count
                    if count > 0 {
                        chip("\(kind.rawValue) \(count)", symbol: kind.symbol, isOn: category == kind) {
                            category = category == kind ? nil : kind
                        }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: { Label(title, systemImage: symbol) }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(isOn ? Color.accentColor : Color.secondary)
            .controlSize(.small)
    }

    private func toggle(_ item: FXItem) {
        if chosen.contains(item.id) { chosen.remove(item.id) } else { chosen.insert(item.id) }
    }

    /// Hands the files to the Send to PC sheet (through the Host or the shared folder).
    private func send(_ items: [FXItem]) {
        let items = items.filter(\.isOnIPad)
        guard !items.isEmpty else { return }
        appState.fileDrop.add(items.map(store.url(for:)))
        store.markSent(items)
        selecting = false
        chosen.removeAll()
        detail = nil
        appState.showingFileDrop = true
    }
}

private struct FXCard: View {
    let item: FXItem
    let url: URL?
    let isChosen: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Rectangle().fill(.fill.tertiary)
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                } else {
                    Image(systemName: item.category.symbol).font(.largeTitle).foregroundStyle(.secondary)
                }
            }
            .frame(height: 104)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(alignment: .bottomLeading) {
                if item.kind == .video, let seconds = item.durationSeconds {
                    Label(FXItem.clock(seconds), systemImage: "play.fill")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(6)
                }
            }
            .overlay(alignment: .topLeading) {
                if item.prismMissing == true {
                    Label("Not in Prism", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.85), in: .capsule)
                        .foregroundStyle(.white)
                        .padding(6)
                } else if !item.isOnIPad {
                    Label("On the PC", systemImage: "desktopcomputer")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isChosen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(6)
                } else if item.lastSent != nil {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .green)
                        .padding(6)
                        .accessibilityLabel("Sent to the PC")
                }
            }
            Text(item.title).font(.callout.weight(.semibold)).lineLimit(1)
            Text([item.prismBank, item.summary].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .contentShape(.rect)
        .task(id: url) {
            guard let url else { return }
            let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 340, height: 208),
                                                       scale: 2, representationTypes: .thumbnail)
            thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).uiImage
        }
    }
}

private struct FXDetailView: View {
    @State var item: FXItem
    let store: FXLibraryStore
    let send: (FXItem) -> Void
    @State private var player: AVPlayer?
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    private var url: URL? { store.localURL(for: item) }

    private var prismFooter: String {
        let deck = item.deckCategory == nil
            ? "The deck's FX page has Fire, Candle, Lightning, Police, Fireworks and TV. Pick one of those categories to put this on it."
            : "Where Prism has this clip, as the Prism layer's Folder and File show in Titan. With both set, it's on the deck: FX > \(item.category.rawValue)."
        return item.prismPath == nil ? deck : deck + " Sync with Prism sets these from Prism's banks."
    }

    var body: some View {
        Form {
            if let url {
                Section {
                    Group {
                        if item.kind == .video, let player {
                            VideoPlayer(player: player)
                        } else if let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(.rect(cornerRadius: 14))
                    .listRowInsets(EdgeInsets())
                }
            }

            Section {
                TextField("Name", text: $item.title)
                Picker("Category", selection: $item.category) {
                    ForEach(FXItem.Category.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
                TextField("Notes (e.g. which fixtures, speed)", text: $item.notes, axis: .vertical)
                    .lineLimit(2 ... 5)
            }

            Section {
                if let bank = item.prismBank { LabeledContent("Prism bank", value: bank) }
                LabeledContent("Folder") {
                    TextField("Number", value: $item.prismFolder, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("File") {
                    TextField("Number", value: $item.prismFile, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Prism (deck FX)")
            } footer: {
                Text(prismFooter)
            }

            Section {
                if !item.summary.isEmpty, item.isOnIPad { LabeledContent("Clip", value: item.summary) }
                if item.isOnIPad { LabeledContent("File", value: item.fileName) }
                if let path = item.prismPath {
                    LabeledContent("On the PC") { Text(path).font(.caption).textSelection(.enabled) }
                }
                if item.prismMissing == true {
                    Label("The last Sync with Prism didn't find this clip in Prism.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                LabeledContent("Added", value: item.added.formatted(date: .abbreviated, time: .shortened))
                if let sent = item.lastSent {
                    LabeledContent("Last sent to PC", value: sent.formatted(date: .abbreviated, time: .shortened))
                }
            } footer: {
                Text("Pixel effects play at the mapped pixel size, so even small clips work well. Keep loops seamless for continuous effects.")
            }

            Section {
                if let url {
                    Button("Send to PC", systemImage: "paperplane.fill") {
                        store.update(item)
                        send(item)
                    }
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
                Button(item.isOnIPad ? "Delete Effect" : "Remove from Library", systemImage: "trash", role: .destructive) {
                    confirmDelete = true
                }
            } footer: {
                if !item.isOnIPad {
                    Text("This clip is on the Titan PC. Removing it here leaves it in Prism, and the next Sync with Prism brings it back while Prism has it.")
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") {
                    store.update(item)
                    dismiss()
                }
            }
        }
        .onAppear {
            if item.kind == .video, let url {
                let player = AVPlayer(url: url)
                player.isMuted = true
                self.player = player
                player.play()
            }
        }
        .onDisappear {
            player?.pause()
            store.update(item)
        }
        .confirmationDialog(item.isOnIPad ? "Delete \(item.title)?" : "Remove \(item.title) from the library?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(item.isOnIPad ? "Delete" : "Remove", role: .destructive) {
                store.delete(item)
                dismiss()
            }
        }
    }
}
