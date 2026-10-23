// Remote/RDPSettings.swift
import Foundation

// TODO(M5): host, user, resolution and colour depth for the FreeRDP session.
// The password lives in the Keychain (M6), never in this struct or UserDefaults.
// See the "FreeRDP on iOS" section of the build plan:
// https://claude.ai/artifact/PXtiepzci194FMHiHaynGM
struct RDPSettings: Codable, Hashable {
    var host: String = ""
    var user: String = ""
    var width: Int = 0
    var height: Int = 0
    var colorDepth: Int = 32
}
