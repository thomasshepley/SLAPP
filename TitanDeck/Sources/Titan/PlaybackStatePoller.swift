// Titan/PlaybackStatePoller.swift
import Foundation

/// Polls Titan once a second for which playbacks are active, so their deck
/// keys can light up (M8). Only polls while Titan's heartbeat says it's there.
@MainActor
final class PlaybackStatePoller: ObservableObject {
    enum Support: Equatable {
        case unknown
        case working
        /// Titan answered but didn't include playback user numbers.
        case noUserNumbers
    }

    @Published private(set) var support: Support = .unknown
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled { onChange?([]) }
        }
    }

    /// Called with the active user numbers whenever they change.
    var onChange: ((Set<Int>) -> Void)?
    /// Called with every playback handle Titan reports, each poll.
    var onHandles: (([PlaybackHandleState]) -> Void)?
    /// Called with Titan's workspace names (by user number) every 15 s.
    var onWorkspaceNames: (([Int: String]) -> Void)?

    private static let enabledKey = "liveKeyState"
    private var task: Task<Void, Never>?
    private var lastActive: Set<Int> = []

    init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func start(client: TitanClient, isTitanReachable: @escaping @MainActor () -> Bool) {
        task?.cancel()
        task = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                if tick % 15 == 0, isTitanReachable(), let workspaces = await client.handles(group: "Workspaces") {
                    self.onWorkspaceNames?(TitanHandlesParser.legendsByUserNumber(workspaces))
                }
                tick += 1
                if self.isEnabled, isTitanReachable(), let handles = await client.playbackHandles() {
                    self.onHandles?(handles)
                    if let active = TitanHandlesParser.activeUserNumbers(handles) {
                        self.support = .working
                        if active != self.lastActive {
                            self.lastActive = active
                            self.onChange?(active)
                        }
                    } else {
                        self.support = .noUserNumbers
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
