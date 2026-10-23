// Support/ConnectionLogStore.swift
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Keeps the connection log on disk (Application Support) so a soak test
/// survives the app being closed, and hands it to the share sheet as CSV.
@MainActor
final class ConnectionLogStore: ObservableObject {
    @Published private(set) var log: ConnectionLog

    private let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory
            ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        fileURL = base.appendingPathComponent("connection-log.json")
        if let data = try? Data(contentsOf: fileURL),
           let events = try? JSONDecoder().decode([ConnectionEvent].self, from: data) {
            log = ConnectionLog(events: events)
        } else {
            log = ConnectionLog()
        }
    }

    func record(_ source: ConnectionEvent.Source, _ status: ConnectionEvent.Status, _ detail: String) {
        guard log.record(ConnectionEvent(date: Date(), source: source, status: status, detail: detail)) else { return }
        save()
    }

    func clear() {
        log.clear()
        save()
    }

    var export: ConnectionLogCSV {
        ConnectionLogCSV(log: log)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(log.events).write(to: fileURL, options: .atomic)
        } catch {
            Log.deck("Couldn't save connection log: \(error)")
        }
    }
}

/// The log as a CSV file for the share sheet (AirDrop, Mail, Files...).
struct ConnectionLogCSV: Transferable {
    let log: ConnectionLog

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmm"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("TitanDeck-connection-log-\(formatter.string(from: Date())).csv")
            try item.log.csv().write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
