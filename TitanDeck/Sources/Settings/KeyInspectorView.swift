// Settings/KeyInspectorView.swift
import SwiftUI
import UIKit

/// Edits one key: label, colour, icon and action, with a live preview drawn by
/// the same renderer the Stream Deck uses. Nothing is saved until Save.
struct KeyInspectorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var key: KeyDefinition
    @State private var draft: ActionDraft
    private let isNew: Bool
    private let pageCount: Int
    private let onSave: (KeyDefinition) -> Void
    private let onClear: () -> Void
    private let onTest: (TitanAction) -> Void

    static let swatches = ["#1E7D32", "#B23B1E", "#2D4FA3", "#C78A00", "#6A3FA0", "#0E7C86", "#2A2A2A", "#000000"]
    static let symbols = ["play.fill", "stop.fill", "pause.fill", "forward.end.fill", "arrow.right.square",
                          "arrow.left.square", "lightbulb.fill", "sun.max.fill", "bolt.fill", "sparkles"]

    init(key: KeyDefinition?, index: Int, pageCount: Int,
         onSave: @escaping (KeyDefinition) -> Void,
         onClear: @escaping () -> Void,
         onTest: @escaping (TitanAction) -> Void) {
        let start = key ?? KeyDefinition(index: index, label: "")
        _key = State(initialValue: start)
        _draft = State(initialValue: ActionDraft(action: start.action))
        isNew = key == nil
        self.pageCount = pageCount
        self.onSave = onSave
        self.onClear = onClear
        self.onTest = onTest
    }

    /// The key as it will be saved.
    private var edited: KeyDefinition {
        var result = key
        result.action = draft.action
        let symbol = key.sfSymbol?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        result.sfSymbol = symbol.isEmpty ? nil : symbol
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                Section {
                    TextField("Label", text: $key.label, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Label")
                } footer: {
                    Text("Press Return to split the label over two lines.")
                }
                colourSection
                iconSection
                actionSection
                Section {
                    Button("Test now", systemImage: "bolt.fill") {
                        if let action = draft.action { onTest(action) }
                    }
                    .disabled(!(draft.action?.isRemote ?? false))
                    Button("Clear key", systemImage: "trash", role: .destructive) {
                        onClear()
                        dismiss()
                    }
                    .disabled(isNew)
                }
            }
            .navigationTitle("Key \(key.index + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(edited)
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                Image(uiImage: DeckRenderer.image(for: edited, size: CGSize(width: 96, height: 96)))
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private var colourSection: some View {
        Section("Colour") {
            HStack(spacing: 12) {
                ForEach(Self.swatches, id: \.self) { hex in
                    Button {
                        key.colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(uiColor: UIColor(hex: hex)))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                            .overlay {
                                if key.colorHex.uppercased() == hex {
                                    Circle().strokeBorder(.white, lineWidth: 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(hex)")
                }
            }
            ColorPicker("Custom colour", selection: colourBinding, supportsOpacity: false)
        }
    }

    private var iconSection: some View {
        Section {
            TextField("SF Symbol name (optional)", text: symbolBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Button {
                        key.sfSymbol = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("No icon")
                    ForEach(Self.symbols, id: \.self) { name in
                        Button {
                            key.sfSymbol = name
                        } label: {
                            Image(systemName: name)
                        }
                        .accessibilityLabel(name)
                    }
                }
                .font(.title3)
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Icon")
        } footer: {
            Text("Any SF Symbol name works. Browse them in Apple's free SF Symbols app.")
        }
    }

    private var actionSection: some View {
        Section {
            Picker("Action", selection: $draft.kind) {
                ForEach(ActionDraft.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            actionFields
        } header: {
            Text("Action")
        } footer: {
            actionFooter
        }
    }

    @ViewBuilder
    private var actionFields: some View {
        switch draft.kind {
        case .go, .release:
            playbackField
        case .fader:
            playbackField
            VStack(alignment: .leading) {
                LabeledContent("Level", value: "\(Int((draft.level * 100).rounded()))%")
                Slider(value: $draft.level, in: 0...1, step: 0.05)
            }
        case .macro:
            TextField("Macro id", text: $draft.macroId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .goToPage:
            Picker("Page", selection: $draft.page) {
                ForEach(0..<max(pageCount, 1), id: \.self) { index in
                    Text("Page \(index + 1)").tag(index)
                }
            }
        case .raw:
            TextField("e.g. Playbacks/KillAllPlaybacks", text: $draft.rawPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
        case .none, .nextPage, .previousPage, .openSettings:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actionFooter: some View {
        switch draft.kind {
        case .go, .release, .fader:
            Text("The playback's user number in Titan.")
        case .macro:
            Text("Titan's macro id string, not its user number.")
        case .raw:
            Text("Sent as http://<Titan>:4430/titan/script/2/<path>. See api.avolites.com for functions.")
        default:
            EmptyView()
        }
    }

    private var playbackField: some View {
        Stepper(value: $draft.playback, in: 1...9999) {
            LabeledContent("Playback") {
                TextField("Number", value: $draft.playback, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
            }
        }
    }

    // MARK: - Bindings

    private var colourBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: UIColor(hex: key.colorHex)) },
            set: { key.colorHex = HexColor(UIColor($0)).hexString }
        )
    }

    private var symbolBinding: Binding<String> {
        Binding(
            get: { key.sfSymbol ?? "" },
            set: { key.sfSymbol = $0.isEmpty ? nil : $0 }
        )
    }
}
