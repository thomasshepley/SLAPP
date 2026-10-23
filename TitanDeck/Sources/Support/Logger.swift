// Support/Logger.swift
import Foundation
#if canImport(os)
import os
#endif

/// Thin wrapper over os.Logger so call sites stay one-liners. View the output in
/// Console.app on a Mac, or via the recent-calls list on the Settings screen.
enum Log {
    #if canImport(os)
    private static let titanLogger = Logger(subsystem: "uk.co.elexproductions.titandeck", category: "titan")
    private static let deckLogger = Logger(subsystem: "uk.co.elexproductions.titandeck", category: "deck")
    #endif

    static func titan(_ message: String) {
        #if canImport(os)
        titanLogger.info("\(message, privacy: .public)")
        #else
        print("[titan] \(message)")
        #endif
    }

    static func deck(_ message: String) {
        #if canImport(os)
        deckLogger.info("\(message, privacy: .public)")
        #else
        print("[deck] \(message)")
        #endif
    }
}
