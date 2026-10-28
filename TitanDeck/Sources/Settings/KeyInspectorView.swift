// Settings/KeyInspectorView.swift
import SwiftUI
import UIKit

/// Edits one key: label, colour, icon and action, with a live preview drawn by
/// the same renderer the Stream Deck uses. Nothing is saved until Save.
struct KeyInspectorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var key: KeyDefinition
    @State private var draft: ActionDraft
    @State private var previewPressed = false
    @FocusState private var focusedField: Field?

    private enum Field { case label, pressedLabel }
    private let isNew: Bool
    private let pageCount: Int
    private let onSave: (KeyDefinition) -> Void
    private let onClear: () -> Void
    private let onTest: (TitanAction) -> Void

    static let symbols = ["play.fill", "stop.fill", "pause.fill", "forward.end.fill", "arrow.right.square",
                          "arrow.left.square", "lightbulb.fill", "sun.max.fill", "bolt.fill", "sparkles"]
    /// Quick picks for show work; the emoji keyboard has the rest.
    static let emojis = ["💡", "🔥", "⚡️", "🚨", "🎆", "🌈", "☀️", "🌙", "❄️", "🌊", "⭐️", "🎬",
                         "🎵", "🎤", "🚓", "🔴", "🟢", "🔵", "⚪️", "⛔️", "✅", "▶️", "⏹️", "⏸️"]

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
        result.emoji = key.emoji.flatMap(KeyDefinition.cleanEmoji)
        if var style = key.pressedStyle {
            let label = style.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            style.label = label.isEmpty ? nil : style.label
            style.emoji = style.emoji.flatMap(KeyDefinition.cleanEmoji)
            let pressedSymbol = style.sfSymbol?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            style.sfSymbol = pressedSymbol.isEmpty ? nil : pressedSymbol
            // "While live" only makes sense for a playback key.
            if style.mode == .live, draft.action?.playbackUserNumber == nil { style.mode = .held }
            result.pressedStyle = style
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                Section {
                    TextField("Label", text: $key.label, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .label)
                        .wholeRowTapFocuses { focusedField = .label }
                } header: {
                    Text("Label")
                } footer: {
                    Text("Press Return to split the label over two lines.")
                }
                colourSection
                iconSection
                actionSection
                pressedSection
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
            VStack(spacing: 10) {
                Image(uiImage: DeckRenderer.image(for: edited, size: CGSize(width: 96, height: 96),
                                                  overlay: previewPressed ? .pressed : .none,
                                                  isLatched: previewPressed))
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: 40, perform: {}) { pressing in
                        previewPressed = pressing
                    }
                if key.pressedStyle != nil {
                    Picker("Preview", selection: $previewPressed) {
                        Text("Normal").tag(false)
                        Text("Pressed").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private var colourSection: some View {
        Section {
            SwatchGrid(hex: $key.colorHex)
        } header: {
            Text("Colour")
        } footer: {
            Text("Add to palette keeps a custom colour with the swatches for every key. Long-press one of yours to remove it.")
        }
    }

    private var iconSection: some View {
        Section {
            IconFields(sfSymbol: $key.sfSymbol, emoji: $key.emoji, emptyTitle: "None")
        } header: {
            Text("Icon")
        } footer: {
            Text("Any SF Symbol name works (browse them in Apple's free SF Symbols app), or any emoji from the emoji keyboard. With no label, the icon fills the key.")
        }
    }

    private var pressedSection: some View {
        Section {
            Toggle("Change the look when pressed", isOn: pressedEnabled)
            if key.pressedStyle != nil {
                Picker("Show it", selection: pressedMode) {
                    ForEach(KeyDefinition.PressedStyle.Mode.allCases) { mode in
                        if mode != .live || draft.action?.playbackUserNumber != nil {
                            Text(mode.title).tag(mode)
                        }
                    }
                }
                SwatchGrid(hex: pressedColour)
                TextField("Label (blank keeps the normal one)", text: pressedLabel, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .pressedLabel)
                    .wholeRowTapFocuses { focusedField = .pressedLabel }
                IconFields(sfSymbol: pressedBinding(\.sfSymbol), emoji: pressedBinding(\.emoji), emptyTitle: "Same")
            }
        } header: {
            Text("When pressed")
        } footer: {
            Text(pressedFooter)
        }
    }

    private var pressedFooter: String {
        switch key.pressedStyle?.resolvedMode {
        case nil: return "Give the key a second look: a different colour, label or icon."
        case .held?: return "Shows while your finger is on the key."
        case .latch?: return "Press once to switch to this look, press again to switch back. Good for on/off keys."
        case .live?: return "Shows while the playback is running on Titan, so you can see what's up at a glance."
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
        case .keypadDigit:
            Picker("Digit", selection: $draft.digit) {
                ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
            }
        case .intensity:
            Stepper(value: $draft.percent, in: -100...100, step: 1) {
                LabeledContent("Change", value: "\(draft.percent > 0 ? "+" : "")\(Int(draft.percent))%")
            }
        case .cueGo:
            Stepper("GO slot \(draft.slot)", value: $draft.slot, in: 1...32)
        case .cueFade:
            Stepper("GO slot \(draft.slot)", value: $draft.slot, in: 1...32)
            Picker("Fade", selection: $draft.fadeOut) {
                Text("Fade in").tag(false)
                Text("Fade out").tag(true)
            }
            .pickerStyle(.segmented)
        case .workspace:
            Stepper(value: $draft.playback, in: 1...9999) {
                LabeledContent("Workspace") {
                    TextField("Number", value: $draft.playback, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                }
            }
        case .colourTemperature:
            Picker("Preset", selection: $draft.kelvin) {
                ForEach(DeckFlow.cctPresets, id: \.self) { Text("\($0)K").tag($0) }
                if !DeckFlow.cctPresets.contains(draft.kelvin) { Text("\(draft.kelvin)K").tag(draft.kelvin) }
            }
            Stepper(value: $draft.kelvin, in: 1000...20000, step: 100) {
                LabeledContent("Kelvin", value: "\(draft.kelvin)K")
            }
        case .none, .nextPage, .previousPage, .openSettings, .keypadAt, .keypadEnter, .keypadExit,
             .keypadClear, .keypadThro, .mainMenu, .colourPresets, .connectCue, .flashSelection,
             .highlight, .nextFixture, .previousFixture, .allFixtures:
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
        case .keypadDigit, .keypadAt, .keypadEnter, .keypadClear, .keypadThro:
            Text("Works on Titan's command line, like the console keypad.")
        case .intensity:
            Text("Nudges the selected fixtures' intensity. Negative numbers bring it down.")
        case .colourTemperature:
            Text("Recalls the colour palette in Titan named \(draft.kelvin)K on the selected fixtures. Make global colour palettes named 2700K, 3200K... once and every fixture type uses its own CCT channel.")
        case .colourPresets:
            Text("Shows the colour temperature keys, with a way back to the keypad.")
        case .cueGo:
            Text("Fires whichever Titan cue Connect Cue put on this slot. Leave the label blank to show the cue's name.")
        case .cueFade:
            Text("Shows the slot's fade time; press it on the deck to pick a new one. Setting cue times from the deck is new - check it on the console.")
        case .connectCue:
            Text("Turns the GO slot keys red: press one, then a Titan page, then a cue to put on it.")
        case .highlight, .nextFixture, .previousFixture, .allFixtures:
            Text("Rig check, like the desk's Highlight, Next and Prev keys: Next and Prev step through the selected fixtures one at a time, and All goes back to the whole selection.")
        case .flashSelection:
            Text("Hold to take the selected fixtures to 0%, let go to put them back. Fades follow Settings > Deck > Flash fades.")
        case .workspace:
            Text("The workspace's user number in Titan (its saved window layout). Leave the label blank and the key shows the workspace's name from Titan.")
        case .mainMenu:
            Text("On the keypad it reads Quick Keys and a tap goes there; on any other page it shows the page's name and a tap goes back to the keypad. Hold for a second for the menu of all pages.")
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

    private var pressedEnabled: Binding<Bool> {
        Binding(
            get: { key.pressedStyle != nil },
            set: { on in
                key.pressedStyle = on ? KeyDefinition.PressedStyle(mode: .held, colorHex: "#B23B1E") : nil
                previewPressed = on
            }
        )
    }

    private var pressedMode: Binding<KeyDefinition.PressedStyle.Mode> {
        Binding(
            get: { key.pressedStyle?.resolvedMode ?? .held },
            set: { key.pressedStyle?.mode = $0 }
        )
    }

    private var pressedColour: Binding<String> {
        Binding(
            get: { key.pressedStyle?.colorHex ?? key.colorHex },
            set: { key.pressedStyle?.colorHex = $0 }
        )
    }

    private var pressedLabel: Binding<String> {
        Binding(
            get: { key.pressedStyle?.label ?? "" },
            set: { key.pressedStyle?.label = $0 }
        )
    }

    private func pressedBinding(_ path: WritableKeyPath<KeyDefinition.PressedStyle, String?>) -> Binding<String?> {
        Binding(
            get: { key.pressedStyle?[keyPath: path] },
            set: { key.pressedStyle?[keyPath: path] = $0 }
        )
    }
}

/// The palette: built-in swatches, then your saved colours, then a picker
/// for anything else with a button to keep it.
private struct SwatchGrid: View {
    @Binding var hex: String
    @AppStorage(DeckPalette.storageKey) private var stored = ""

    private var custom: [String] { DeckPalette.decode(stored) }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 12)], spacing: 12) {
            ForEach(DeckPalette.builtIn + custom, id: \.self) { colour in
                swatch(colour, isCustom: custom.contains(colour))
            }
        }
        .padding(.vertical, 4)
        HStack {
            ColorPicker("Custom colour", selection: colourBinding, supportsOpacity: false)
            Button("Add to palette", systemImage: "plus.circle.fill") {
                withAnimation(.snappy) { stored = DeckPalette.encode(DeckPalette.adding(hex, to: custom)) }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonStyle(.borderless)
            .disabled((DeckPalette.builtIn + custom).contains(hex.uppercased()))
            .accessibilityLabel("Add this colour to the palette")
        }
    }

    private func swatch(_ colour: String, isCustom: Bool) -> some View {
        Button {
            hex = colour
        } label: {
            Circle()
                .fill(Color(uiColor: UIColor(hex: colour)))
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(.white.opacity(0.25)))
                .overlay {
                    if hex.uppercased() == colour {
                        Circle().strokeBorder(.white, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isCustom {
                Button("Remove from palette", systemImage: "trash", role: .destructive) {
                    withAnimation(.snappy) { stored = DeckPalette.encode(DeckPalette.removing(colour, from: custom)) }
                }
            }
        }
        .accessibilityLabel("Colour \(colour)")
    }

    private var colourBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: UIColor(hex: hex)) },
            set: { hex = HexColor(UIColor($0)).hexString }
        )
    }
}

/// Icon choice: none (or "same" for the pressed look), an SF Symbol, or an emoji.
private struct IconFields: View {
    @Binding var sfSymbol: String?
    @Binding var emoji: String?
    let emptyTitle: String

    private enum Kind: Hashable { case none, symbol, emoji }

    private var kind: Binding<Kind> {
        Binding(
            get: { emoji != nil ? .emoji : sfSymbol != nil ? .symbol : .none },
            set: { new in
                switch new {
                case .none:
                    sfSymbol = nil
                    emoji = nil
                case .symbol:
                    emoji = nil
                    if sfSymbol == nil { sfSymbol = "lightbulb.fill" }
                case .emoji:
                    sfSymbol = nil
                    if emoji == nil { emoji = "💡" }
                }
            }
        )
    }

    var body: some View {
        Picker("Icon", selection: kind) {
            Text(emptyTitle).tag(Kind.none)
            Text("Symbol").tag(Kind.symbol)
            Text("Emoji").tag(Kind.emoji)
        }
        .pickerStyle(.segmented)
        switch kind.wrappedValue {
        case .none:
            EmptyView()
        case .symbol:
            TextField("SF Symbol name", text: text($sfSymbol))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            quickPicks(KeyInspectorView.symbols) { name in
                Button { sfSymbol = name } label: { Image(systemName: name) }
                    .accessibilityLabel(name)
            }
        case .emoji:
            TextField("Emoji", text: text($emoji))
                .font(.title2)
            quickPicks(KeyInspectorView.emojis) { character in
                Button(character) { emoji = character }
            }
        }
    }

    private func quickPicks<Content: View>(_ items: [String], @ViewBuilder button: @escaping (String) -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(items, id: \.self) { button($0) }
            }
            .font(.title3)
            .buttonStyle(.borderless)
        }
    }

    private func text(_ value: Binding<String?>) -> Binding<String> {
        Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0 })
    }
}

private extension View {
    /// A multi-line TextField in a Form only takes taps on its text, so an
    /// empty one is hard to hit. This makes the whole row bring up the keyboard.
    func wholeRowTapFocuses(_ focus: @escaping () -> Void) -> some View {
        frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            // Behind the field, so taps on the text still place the cursor.
            .background {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: focus)
            }
    }
}
