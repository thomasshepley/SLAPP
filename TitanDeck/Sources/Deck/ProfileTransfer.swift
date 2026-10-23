// Deck/ProfileTransfer.swift
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A deck profile as a JSON file for the share sheet / Files (AirDrop, iCloud
/// Drive, email to the next job's iPad).
struct ProfileFile: Transferable {
    let profile: DeckProfile

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            let safeName = item.profile.name.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }.joined(separator: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("TitanDeck-\(safeName.isEmpty ? "profile" : safeName).json")
            try ProfileCoding.encode(item.profile).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
