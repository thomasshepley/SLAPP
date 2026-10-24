// Remote/RDPQuality.swift
import Foundation

/// How the remote desktop trades picture for bandwidth. Half is on the iPad
/// (which visual effects Windows draws for this connection), half on the PC
/// through TitanDeck Host (Windows' image quality, bandwidth mode and frame
/// rate). The iPad's FreeRDP has no H.264, so it gets the progressive
/// RemoteFX codecs these settings tune.
struct RDPQuality: Codable, Hashable {
    enum Preset: String, Codable, CaseIterable, Identifiable {
        case best
        case balanced
        case weakSignal

        var id: Self { self }

        var title: String {
            switch self {
            case .best: "Best"
            case .balanced: "Balanced"
            case .weakSignal: "Weak signal"
            }
        }

        var detail: String {
            switch self {
            case .best: "Wired, or strong Wi-Fi near the AP. Sharpest picture, 60 fps, all Windows effects."
            case .balanced: "Normal Wi-Fi. Windows' standard quality at 30 fps, no wallpaper or animations."
            case .weakSignal: "Bad Wi-Fi on set. Lowest bandwidth: softer picture, plain Windows, stays responsive."
            }
        }

        var symbol: String {
            switch self {
            case .best: "sparkles.tv"
            case .balanced: "wifi"
            case .weakSignal: "wifi.exclamationmark"
            }
        }
    }

    /// Which Windows visual effects to ask for (FreeRDP's connection type).
    enum Visuals: String, Codable, CaseIterable, Identifiable {
        case full
        case reduced
        case minimal

        var id: Self { self }

        var title: String {
            switch self {
            case .full: "Everything"
            case .reduced: "No wallpaper or animations"
            case .minimal: "Plain"
            }
        }

        /// CONNECTION_TYPE_LAN / BROADBAND_HIGH / BROADBAND_LOW.
        var connectionType: UInt32 {
            switch self {
            case .full: 6
            case .reduced: 4
            case .minimal: 2
            }
        }
    }

    /// Windows' "image quality for RemoteFX adaptive graphics".
    enum PCImageQuality: String, Codable, CaseIterable, Identifiable {
        case lossless, high, medium, low
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    /// Windows' "RemoteFX adaptive graphics" mode.
    enum PCProfile: String, Codable, CaseIterable, Identifiable {
        case automatic
        case minimumBandwidth
        case serverScalability

        var id: Self { self }

        var title: String {
            switch self {
            case .automatic: "Windows chooses"
            case .minimumBandwidth: "Lowest bandwidth"
            case .serverScalability: "Lightest on the PC"
            }
        }
    }

    var visuals: Visuals
    var pcImageQuality: PCImageQuality
    var pcProfile: PCProfile
    /// 30 (Windows' normal) or 60.
    var pcFrameRate: Int

    static func preset(_ preset: Preset) -> RDPQuality {
        switch preset {
        case .best: RDPQuality(visuals: .full, pcImageQuality: .high, pcProfile: .automatic, pcFrameRate: 60)
        case .balanced: RDPQuality(visuals: .reduced, pcImageQuality: .medium, pcProfile: .automatic, pcFrameRate: 30)
        case .weakSignal: RDPQuality(visuals: .minimal, pcImageQuality: .low, pcProfile: .minimumBandwidth, pcFrameRate: 30)
        }
    }

    /// The preset these settings match, or nil when they've been customised.
    var preset: Preset? { Preset.allCases.first { RDPQuality.preset($0) == self } }

    /// Just the PC half, for comparing with what the Host reports.
    var pcSettings: PCSettings { PCSettings(imageQuality: pcImageQuality, profile: pcProfile, frameRate: pcFrameRate) }

    struct PCSettings: Equatable {
        var imageQuality: PCImageQuality
        var profile: PCProfile
        var frameRate: Int
    }

    /// What the Host's rdp/quality endpoint takes.
    var hostRequest: HostRdpQualityRequest {
        HostRdpQualityRequest(preset: nil, imageQuality: pcImageQuality.rawValue, profile: pcProfile.rawValue,
                              frameRate: pcFrameRate)
    }

    /// The PC half of what the Host reported, if it makes sense.
    static func pcSettings(from host: HostRdpQuality) -> PCSettings? {
        guard let quality = PCImageQuality(rawValue: host.imageQuality),
              let profile = PCProfile(rawValue: host.profile) else { return nil }
        return PCSettings(imageQuality: quality, profile: profile, frameRate: host.frameRate >= 60 ? 60 : 30)
    }

    /// Plain words for a summary row: "High quality, 60 fps, all effects".
    var summary: String {
        var parts = ["\(pcImageQuality.title) quality", "\(pcFrameRate) fps"]
        if pcProfile == .minimumBandwidth { parts.append("lowest bandwidth") }
        parts.append(visuals == .full ? "all effects" : visuals == .reduced ? "fewer effects" : "plain Windows")
        return parts.joined(separator: ", ")
    }
}
