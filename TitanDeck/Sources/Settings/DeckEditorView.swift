// Settings/DeckEditorView.swift
import SwiftUI

/// M4 deck editor: a grid laid out like the physical deck, one page at a time.
/// Tap a key to edit it. Every change saves straight away and shows on the
/// Stream Deck, which follows whichever page is being edited.
struct DeckEditorView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var deck: DeckSessionController

    @State private var pageIndex = 0
    @State private var editingKey: EditingKey?
    @State private var isRenaming = false
    @State private var newPageName = ""
    @State private var confirmDelete = false

    private struct EditingKey: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private var profile: DeckProfile { deck.profile }

    private var safePageIndex: Int {
        min(max(pageIndex, 0), max(profile.pages.count - 1, 0))
    }

    private var page: DeckPage? {
        profile.pages.indices.contains(safePageIndex) ? profile.pages[safePageIndex] : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pagePicker
                keyGrid
                Text("Tap a key to edit it. Changes save straight away and show on the Stream Deck.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Deck profile")
        .toolbar { pageMenu }
        .sheet(item: $editingKey) { item in
            KeyInspectorView(
                key: page?.key(at: item.index),
                index: item.index,
                pageCount: profile.pages.count,
                onSave: { key in edit { $0.setKey(key, onPage: safePageIndex) } },
                onClear: { edit { $0.clearKey(at: item.index, onPage: safePageIndex) } },
                onTest: { action in appState.fire(action) }
            )
        }
        .alert("Rename page", isPresented: $isRenaming) {
            TextField("Page name", text: $newPageName)
            Button("Save") { edit { $0.renamePage(at: safePageIndex, to: newPageName) } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \"\(page?.name ?? "")\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete page", role: .destructive) {
                let removed = safePageIndex
                edit { $0.removePage(at: removed) }
                pageIndex = max(removed - 1, 0)
            }
        } message: {
            Text("Keys elsewhere that jump to this page will switch to \"next page\" instead.")
        }
        .onAppear { pageIndex = deck.currentPageIndex }
        .onChange(of: pageIndex) { _, newValue in deck.showPage(newValue) }
    }

    // MARK: - Pieces

    private var pagePicker: some View {
        Picker("Page", selection: $pageIndex) {
            ForEach(profile.pages.indices, id: \.self) { index in
                Text(profile.pages[index].name).tag(index)
            }
        }
        .pickerStyle(.segmented)
    }

    private var keyGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: profile.gridColumns)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<profile.keyCount, id: \.self) { index in
                let key = page?.key(at: index)
                Button {
                    editingKey = EditingKey(index: index)
                } label: {
                    Image(uiImage: DeckRenderer.image(for: key, size: CGSize(width: 96, height: 96)))
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.white.opacity(0.15))
                        }
                        .overlay {
                            if key == nil {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key.map { "Key \(index + 1): \($0.label)" } ?? "Empty key \(index + 1)")
            }
        }
    }

    @ToolbarContentBuilder
    private var pageMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Add page", systemImage: "plus") {
                    edit { pageIndex = $0.addPage() }
                }
                Button("Duplicate page", systemImage: "plus.square.on.square") {
                    edit { profile in
                        if let copy = profile.duplicatePage(at: safePageIndex) { pageIndex = copy }
                    }
                }
                Button("Rename page", systemImage: "pencil") {
                    newPageName = page?.name ?? ""
                    isRenaming = true
                }
                Divider()
                Button("Move page left", systemImage: "arrow.left") {
                    let from = safePageIndex
                    edit { $0.movePage(from: from, to: from - 1) }
                    pageIndex = from - 1
                }
                .disabled(safePageIndex == 0)
                Button("Move page right", systemImage: "arrow.right") {
                    let from = safePageIndex
                    edit { $0.movePage(from: from, to: from + 1) }
                    pageIndex = from + 1
                }
                .disabled(safePageIndex >= profile.pages.count - 1)
                Divider()
                Button("Delete page", systemImage: "trash", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(profile.pages.count <= 1)
            } label: {
                Label("Page", systemImage: "ellipsis.circle")
            }
        }
    }

    /// Applies a change to a copy of the profile, then saves it and pushes it to the deck.
    private func edit(_ change: (inout DeckProfile) -> Void) {
        var updated = deck.profile
        change(&updated)
        appState.updateProfile(updated)
    }
}
