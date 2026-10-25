// App/DeviceSetup.swift
import UIKit

/// The iPad is a console surface: landscape only, whatever the rotation lock
/// says, and the screen never locks while TitanDeck is open. iPadOS 26 can
/// ignore the Info.plist orientation list for resizable apps, so the app
/// says it here too. (iPhone keeps portrait for the deck.)
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
        UIDevice.current.userInterfaceIdiom == .pad ? .landscape : .allButUpsideDown
    }

    /// Call whenever the app comes to the front: iOS turns auto-lock back
    /// on by itself while TitanDeck isn't on screen.
    static func applyWhileOpen() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                Log.deck("Couldn't hold landscape: \(error.localizedDescription)")
            }
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}
