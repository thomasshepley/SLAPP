// Slate/SlateBookView.swift
import SwiftUI

/// The Slate Book: the slate showing with the same buttons as the deck's
/// Slate page, then the day's slates (newest first), each take with the
/// changes logged during it. Match shows what's different on stage now from
/// any line, biggest first.
struct SlateBookView: View {
    @ObservedObject var store: SlateStore
    @State private var askingSlate = false
    @State private var typedSlate = ""
    @State private var correcting = false
    @State private var correctSlate = ""
    @State private var correctTake = ""
    @State private var matching: HostSlateEntry?
    @State private var noting: HostSlateEntry?
    @State private var noteText = ""

    var body: some View {
        NavigationStack {
            List {
                Section { header }
                if let problem = store.problem {
                    Section {
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
                if let book = store.book {
                    if book.entries.isEmpty {
                        Section {
                            Text(store.isViewingToday
                                 ? "Nothing logged today yet. Set the lights, then NEW SLATE (here or on the deck's Slate page) logs the look; TAKE + logs each take, and changes in between log themselves once the lights are still for a few seconds."
                                 : "Nothing was logged on \(book.day).")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(SlateText.grouped(book.entries)) { slate in
                        Section {
                            ForEach(slate.takes) { take in
                                TakeRow(take: take, match: { matching = $0 }, note: { entry in
                                    noteText = entry.note ?? ""
                                    noting = entry
                                })
                            }
                        } header: {
                            SlateHeader(slate: slate)
                        }
                    }
                }
            }
            .navigationTitle("Slate Book")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { dayMenu }
            }
            .task { await store.keepRefreshing() }
            .sheet(item: $matching) { entry in
                MatchView(store: store, entry: entry)
            }
            .alert("New slate", isPresented: $askingSlate) {
                TextField("Slate, e.g. 140", text: $typedSlate)
                    .textInputAutocapitalization(.characters)
                Button("Log") { store.run(.newSlate(typedSlate.isEmpty ? nil : typedSlate)) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Leave it blank for the next slate. The look on stage is logged as take 1.")
            }
            .alert("Put the slate right", isPresented: $correcting) {
                TextField("Slate", text: $correctSlate)
                    .textInputAutocapitalization(.characters)
                TextField("Take", text: $correctTake)
                    .keyboardType(.numberPad)
                Button("Save") {
                    Task { await store.correct(slate: correctSlate, take: Int(correctTake)) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Changes what's showing without logging a look.")
            }
            .alert("Note", isPresented: Binding(get: { noting != nil }, set: { if !$0 { noting = nil } })) {
                TextField("e.g. DoP asked for less backlight", text: $noteText)
                Button("Save") {
                    if let entry = noting { Task { await store.note(entry, noteText) } }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - The slate showing

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                big("SLATE", store.state?.slate ?? "-")
                big("TAKE", store.state.map { String($0.take) } ?? "-")
                Spacer()
                Button("Put Right", systemImage: "pencil") {
                    correctSlate = store.state?.slate ?? ""
                    correctTake = store.state.map { String($0.take) } ?? ""
                    correcting = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(store.state == nil)
            }
            HStack(spacing: 12) {
                Picker("Day or night", selection: Binding(
                    get: { store.state?.night ?? false },
                    set: { night in if night != store.state?.night { store.run(.toggleNight) } })) {
                    Label("Day", systemImage: "sun.max.fill").tag(false)
                    Label("Night", systemImage: "moon.stars.fill").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                Toggle(isOn: Binding(get: { store.state?.fx ?? false },
                                     set: { fx in if fx != store.state?.fx { store.run(.toggleFx) } })) {
                    Label("FX", systemImage: "sparkles")
                }
                .toggleStyle(.button)
            }
            .disabled(store.state == nil)
            HStack(spacing: 10) {
                Button {
                    store.run(.newSlate(nil))
                } label: {
                    FittingLabel("New Slate", systemImage: "film")
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .contextMenu {
                    Button("Type a Slate...", systemImage: "keyboard") {
                        typedSlate = ""
                        askingSlate = true
                    }
                }
                Button {
                    store.run(.take)
                } label: {
                    FittingLabel("Take +", systemImage: "plus.circle")
                }
                .buttonStyle(.glassProminent)
                Button {
                    store.run(.letter)
                } label: {
                    FittingLabel("Letter", systemImage: "character")
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            .disabled(store.busy || !store.isViewingToday)
            Text(statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func big(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
        }
    }

    private var statusLine: String {
        guard let book = store.book else { return "Kept by TitanDeck Host (0.13 or later) from Titan's sACN." }
        guard book.listening else { return "No sACN from Titan reaching the Host: nothing can be logged." }
        let named = book.patched > 0 ? "\(book.patched) fixtures named from Titan's patch" : "no patch yet, so changes are by DMX address"
        return "Logging Titan's output · \(named). Hold New Slate to type a slate number."
    }

    private var dayMenu: some View {
        Menu {
            Button("Today") { store.day = nil }
            if let days = store.book?.days, !days.isEmpty {
                Divider()
                ForEach(days, id: \.self) { day in
                    Button(day) { store.day = day }
                }
            }
        } label: {
            Label(store.day ?? "Today", systemImage: "calendar")
        }
    }
}

/// "Slate 112A · Night · FX · from 09:12"
private struct SlateHeader: View {
    let slate: SlateText.Slate

    var body: some View {
        HStack(spacing: 8) {
            Text("Slate \(slate.slate)").font(.headline)
            Text(SlateText.night(slate.night))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(slate.night ? Color.indigo.opacity(0.25) : Color.orange.opacity(0.25), in: .capsule)
            if slate.fx {
                Text("FX")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.purple.opacity(0.25), in: .capsule)
            }
            Spacer()
            Text(slate.started.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
    }
}

/// One take: when it started and the look then, then each change logged during it.
private struct TakeRow: View {
    let take: SlateText.Take
    let match: (HostSlateEntry) -> Void
    let note: (HostSlateEntry) -> Void
    @State private var open = false

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            ForEach(take.all) { entry in
                EntryLines(entry: entry)
                    .contextMenu { actions(for: entry) }
                    .swipeActions(edge: .trailing) {
                        Button("Match", systemImage: "scope") { match(entry) }.tint(.blue)
                        Button("Note", systemImage: "note.text") { note(entry) }.tint(.gray)
                    }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take \(take.take)").font(.body.weight(.semibold))
                    if let note = take.all.compactMap(\.note).last {
                        Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                let changes = take.changes.count
                Text(changes == 0 ? "no changes" : "\(changes) change\(changes == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let start = take.all.first {
                    Text(start.time.formatted(date: .omitted, time: .shortened))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu { if let first = take.all.first { actions(for: first) } }
        }
    }

    @ViewBuilder
    private func actions(for entry: HostSlateEntry) -> some View {
        Button("Match Against Now", systemImage: "scope") { match(entry) }
        Button(entry.note == nil ? "Add Note" : "Edit Note", systemImage: "note.text") { note(entry) }
    }
}

/// A line of the book: what kind, when, and what changed (first few).
private struct EntryLines: View {
    let entry: HostSlateEntry
    private static let shown = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.callout.weight(.medium))
                Spacer()
                Text(entry.time.formatted(date: .omitted, time: .standard))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ForEach(entry.changes.prefix(Self.shown), id: \.self) { change in
                Text(SlateText.describe(change))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if entry.changes.count > Self.shown {
                Text("and \(entry.changes.count - Self.shown) more").font(.caption).foregroundStyle(.tertiary)
            }
            if let note = entry.note {
                Label(note, systemImage: "note.text").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        switch entry.kind {
        case "slate": "Slate \(entry.slate), take \(entry.take)"
        case "take": "Take \(entry.take)"
        default: entry.changes.isEmpty ? "Change" : "Change: \(entry.changes.count) thing\(entry.changes.count == 1 ? "" : "s")"
        }
    }

    private var icon: String {
        switch entry.kind {
        case "slate": "film"
        case "take": "camera.aperture"
        default: "slider.horizontal.3"
        }
    }

    private var tint: Color {
        switch entry.kind {
        case "slate": .green
        case "take": .blue
        default: .secondary
        }
    }
}

/// What's different on stage now from a line of the book, biggest first.
private struct MatchView: View {
    @ObservedObject var store: SlateStore
    let entry: HostSlateEntry
    @Environment(\.dismiss) private var dismiss
    @State private var result: HostSlateMatch?
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Slate \(entry.slate), take \(entry.take) at \(entry.time.formatted(date: .omitted, time: .shortened)), against what's on stage now. Before is then, after is now.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let problem {
                    Section { Label(problem, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                } else if let result {
                    if !result.listening {
                        Section { Label("No sACN from Titan right now, so there's nothing to match against.", systemImage: "antenna.radiowaves.left.and.right.slash") }
                    } else if result.differences.isEmpty {
                        Section {
                            Label("It matches: nothing's different.", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Section("\(result.differences.count) different") {
                            ForEach(SlateText.worstFirst(result.differences), id: \.self) { change in
                                HStack {
                                    Text(change.fixture.map(String.init) ?? "-")
                                        .font(.callout.monospacedDigit().weight(.semibold))
                                        .frame(width: 56, alignment: .leading)
                                    Text(change.what).font(.callout)
                                    Spacer()
                                    Text("\(SlateText.percent(change.before)) → \(SlateText.percent(change.after))%")
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(change.after > change.before ? Color.orange : Color.blue)
                                }
                            }
                        }
                    }
                } else {
                    Section { ProgressView() }
                }
            }
            .navigationTitle("Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Again", systemImage: "arrow.clockwise") { Task { await load() } }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        switch await store.match(entry) {
        case .success(let match):
            result = match
            problem = nil
        case .failure(let error):
            problem = SlateStore.message(error)
        }
    }
}

/// A button label that never breaks a word (0.43.1): icon beside the title
/// when there's room, icon above it when there isn't (iPhone Duo folded,
/// with its tab bar down the side), shrinking a little as a last resort.
struct FittingLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .fixedSize()
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
