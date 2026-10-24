// FileDrop/FileDropSetupView.swift
import SwiftUI
import UIKit

/// One-time setup: share a folder on the PC, connect to it in the Files app,
/// then pick it here.
struct FileDropSetupView: View {
    @ObservedObject var store: FileDropStore
    let host: String
    @State private var choosingFolder = false
    @Environment(\.dismiss) private var dismiss

    private var server: String { "smb://\(host.isEmpty ? "<PC address>" : host)" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    step(1, "On the PC, share a folder",
                         "Make a folder, e.g. Desktop\\TitanDeck Drop. Right-click it > Properties > Sharing > Share... Add your Windows user with Read/Write.",
                         symbol: "desktopcomputer")
                    step(2, "Turn on file sharing",
                         "Settings > Network & internet > Advanced sharing settings > Private networks: Network discovery and File and printer sharing on.",
                         symbol: "network")
                    step(3, "Connect in the Files app",
                         "Files > ... (top of Browse) > Connect to Server > \(server). Choose Registered User and sign in with the Windows user and password.",
                         symbol: "folder.badge.person.crop")
                    Button("Copy \(server)", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = server
                    }
                    .disabled(host.isEmpty)
                    step(4, "Choose the folder here",
                         "Tap Choose Folder, go to Browse > Shared > the PC, and pick the shared folder.",
                         symbol: "checkmark.circle")
                } header: {
                    Text("Once only")
                } footer: {
                    Text("TitanDeck uses iOS's own SMB connection from the Files app, so nothing needs installing on the PC. A Microsoft-account Windows login uses the account's email address and password.")
                }

                Section {
                    if let folder = store.folderName {
                        LabeledContent("Folder") {
                            Label(folder, systemImage: "folder.fill").foregroundStyle(.blue)
                        }
                        Button("Choose a Different Folder", systemImage: "folder") { choosingFolder = true }
                        Button("Forget Folder", systemImage: "trash", role: .destructive) { store.forgetFolder() }
                    } else {
                        Button("Choose Folder", systemImage: "folder.badge.plus") { choosingFolder = true }
                            .font(.headline)
                    }
                } header: {
                    Text("PC folder")
                }

                Section {
                    LabeledContent("PC address", value: host.isEmpty ? "Not set" : host)
                } footer: {
                    Text("Used to check the PC is reachable (file sharing port 445). It's the remote desktop address, or the Titan address if that's blank - set in Settings.")
                }
            }
            .navigationTitle("File Drop Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { store.setFolder(url) }
            }
        }
    }

    private func step(_ number: Int, _ title: String, _ detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.blue.gradient, in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}
