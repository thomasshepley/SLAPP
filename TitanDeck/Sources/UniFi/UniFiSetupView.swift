// UniFi/UniFiSetupView.swift
import SwiftUI

/// Connecting to the UniFi console: address and a local admin login.
struct UniFiSetupView: View {
    @ObservedObject var store: UniFiStore
    @State private var password = ""
    @State private var isTesting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Console") {
                        TextField("e.g. 192.168.1.1", text: $store.address)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Username") {
                        TextField("Local admin", text: $store.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Password") {
                        SecureField(store.password.isEmpty ? "Password" : "Saved in the Keychain", text: $password)
                            .multilineTextAlignment(.trailing)
                            .onSubmit(savePassword)
                    }
                    LabeledContent("Site") {
                        TextField("default", text: $store.site)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("UniFi console")
                } footer: {
                    Text("The console's own address: a Dream Machine or Cloud Gateway on 443, or a self-hosted controller on 8443 (type it as 192.168.1.5:8443). The site is \"default\" unless you've made more.")
                }

                Section {
                    Button {
                        savePassword()
                        isTesting = true
                        Task {
                            await store.test()
                            isTesting = false
                        }
                    } label: {
                        HStack {
                            Text("Connect")
                            Spacer()
                            if isTesting { ProgressView() } else { statusLabel }
                        }
                    }
                    .disabled(store.address.isEmpty || store.username.isEmpty || (password.isEmpty && store.password.isEmpty))
                    if case .failed(let message) = store.status {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Label {
                        Text("In UniFi: **Settings > Admins & Users > Create New Admin**, turn on **Restrict to Local Access Only**, and give it the **View Only** role (or Site Admin to run RF scans from here). Use that username and password.")
                    } icon: {
                        Image(systemName: "person.badge.key")
                    }
                    .font(.callout)
                    Label("No internet or API key needed: TitanDeck talks to the console directly, the same way UniFi's own web page does.",
                          systemImage: "wifi.router")
                        .font(.callout)
                } header: {
                    Text("Which login?")
                } footer: {
                    Text("A ui.com account with two-factor won't work offline. The console's certificate is trusted the first time and checked after that.")
                }

                Section {
                    Button("Forget the Console's Certificate", role: .destructive) { store.forgetCertificate() }
                    if let message = store.lastMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("UniFi Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        savePassword()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch store.status {
        case .connected: Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Label("Failed", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .connecting, .notSetUp: EmptyView()
        }
    }

    private func savePassword() {
        guard !password.isEmpty else { return }
        store.password = password
        password = ""
    }
}
