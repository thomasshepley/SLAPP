// Support/ModeBadge.swift
import SwiftUI

/// TEST in orange while in Test mode, so it's obvious; nothing in Show.
struct ModeBadge: View {
    @AppStorage(SettingsKeys.showMode) private var showMode = false

    var body: some View {
        if !showMode {
            Text("TEST")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.orange, in: .capsule)
                .accessibilityLabel("Test mode")
        }
    }
}
