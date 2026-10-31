// App/DeviceSetup.swift
import UIKit

/// The iPad is a console surface: landscape only, whatever the rotation lock
/// says, and the screen never locks while TitanDeck is open. iPadOS 26 can
/// ignore the Info.plist orientation list for resizable apps, so the app
/// says it here too, and (0.39) iPadOS 26 can still turn a landscape-only
/// app to portrait with the rotation lock off, so `holdLandscape` turns it
/// straight back whenever that happens. Landscape either way up, so
/// turning the iPad over still flips it. (iPhone and iPhone Duo turn every way.)
@MainActor
final class TitanDeckAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        DeviceSetup.orientations
    }
}

@MainActor
enum DeviceSetup {
    static var orientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .landscape : .all
    }

    /// Call whenever the app comes to the front: iOS turns auto-lock back
    /// on by itself while TitanDeck isn't on screen.
    static func applyWhileOpen() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            requestLandscape(scene)
        }
    }

    private static var lastRequest = Date.distantPast
    private static var retry: Task<Void, Never>?

    /// Call when the window's shape changes or the iPad is turned: if the
    /// system has put TitanDeck in portrait, ask for landscape again (at
    /// most every half second, with one retry, so a refusal can't loop).
    static func holdLandscape() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let portrait = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.effectiveGeometry.interfaceOrientation.isPortrait }
        guard !portrait.isEmpty else { return }
        let wait = 0.5 - Date().timeIntervalSince(lastRequest)
        guard wait <= 0 else {
            retry?.cancel()
            retry = Task { @MainActor in
                try? await Task.sleep(for: .seconds(wait))
                if !Task.isCancelled { holdLandscape() }
            }
            return
        }
        lastRequest = Date()
        Log.deck("iPadOS turned TitanDeck to portrait: back to landscape")
        portrait.forEach(requestLandscape)
    }

    private static func requestLandscape(_ scene: UIWindowScene) {
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscapeAsHeld)) { error in
            Log.deck("Couldn't hold landscape: \(error.localizedDescription)")
        }
        for window in scene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    /// Landscape the way the iPad is held, if it's held landscape. (The
    /// device's left is the interface's right: both mean the home edge is on the right.)
    private static var landscapeAsHeld: UIInterfaceOrientationMask {
        switch UIDevice.current.orientation {
        case .landscapeLeft: .landscapeRight
        case .landscapeRight: .landscapeLeft
        default: .landscape
        }
    }
}
