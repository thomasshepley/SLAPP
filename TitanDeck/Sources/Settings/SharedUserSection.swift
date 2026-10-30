// Settings/SharedUserSection.swift
import SwiftUI

/// Settings > Share the desk's user (0.42, experimental): the deck's WebAPI
/// client becomes one of the show's users (Titan's Disk > Users), so that
/// with the desk's user its selection and levels may be the desk's own.
struct SharedUserSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var loading = false

    var body: some View {
        Section {
            Toggle(isOn: $appState.sharesDeskUser) {
                Label("Share the desk's user", systemImage: "person.2.fill")
            }
            .disabled(appState.sharedUserId == nil)
            Picker("Desk user", selection: $appState.sharedUserId) {
                Text("Not picked").tag(Int?.none)
                ForEach(appState.titanUsers) { user in
                    Text(user.name).tag(Int?.some(user.id))
                }
                if let id = appState.sharedUserId, !appState.titanUsers.contains(where: { $0.id == id }) {
                    Text("User \(id)").tag(Int?.some(id))
                }
            }
            LabeledContent("Or the user's Titan id") {
                TextField("Titan id", value: $appState.sharedUserId, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
            Button {
                Task {
                    loading = true
                    await appState.loadTitanUsers()
                    loading = false
                }
            } label: {
                if loading {
                    HStack { ProgressView(); Text("Asking Titan...") }
                } else {
                    Label("Find Titan's users", systemImage: "arrow.clockwise")
                }
            }
            .disabled(loading)
            if let status = appState.sharedUserStatus {
                Text(status).font(.callout).foregroundStyle(.secondary)
            }
        } header: {
            Text("Share the desk's user (experimental)")
        } footer: {
            Text("Titan keeps a programmer for each user, and the deck's WebAPI is a user of its own, so what the deck selects doesn't show on the desk. Pick the user the desk is on (Disk > Users on the desk shows it, usually Operator) and turn this on: the deck's WebAPI becomes that user, which may put its selection and levels in the desk's programmer. Titan doesn't document it, so try it with nothing important live. Turn it off to give the WebAPI its own user back.")
        }
        .task {
            if appState.titanUsers.isEmpty { await appState.loadTitanUsers() }
        }
    }
}
