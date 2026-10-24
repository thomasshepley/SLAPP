// Settings/WhatsNewView.swift
import SwiftUI

/// What changed in each version, newest first. Opens on its own once after
/// an update (see RootView), and from Settings > About.
struct WhatsNewView: View {
    var changelog = Changelog.bundled()
    /// Just this version, as shown after an update; nil shows everything.
    var onlyVersion: String?
    @Environment(\.dismiss) private var dismiss

    private var entries: [Changelog.Entry] {
        if let onlyVersion, let entry = changelog.entry(for: onlyVersion) { return [entry] }
        return changelog.entries
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    Section {
                        ForEach(entry.notes, id: \.self) { note in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "sparkle")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                                Text(LocalizedStringKey(note))
                                    .font(.callout)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title.isEmpty ? "Version \(entry.version)" : entry.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                                .textCase(nil)
                            Text("Version \(entry.version)\(entry.date.isEmpty ? "" : " · \(entry.date)")")
                                .font(.caption)
                                .textCase(nil)
                        }
                        .padding(.bottom, 4)
                    }
                }
                if onlyVersion != nil && changelog.entries.count > 1 {
                    NavigationLink("Earlier versions") {
                        WhatsNewList(entries: Array(changelog.entries.dropFirst()))
                    }
                }
            }
            .navigationTitle("What's New")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}

private struct WhatsNewList: View {
    let entries: [Changelog.Entry]

    var body: some View {
        List(entries) { entry in
            Section("\(entry.version) · \(entry.title)") {
                ForEach(entry.notes, id: \.self) { Text(LocalizedStringKey($0)).font(.callout) }
            }
        }
        .navigationTitle("Earlier Versions")
    }
}

extension Bundle {
    /// "0.3.0", from CFBundleShortVersionString.
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
