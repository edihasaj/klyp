import SwiftUI
import AppKit

@main
struct KlypApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings scene gives users a way to reach preferences from the
        // standard ⌘, shortcut once any window is keyed. The status item
        // remains the primary entry point.
        Settings {
            SettingsView()
                .environment(appDelegate.coordinator.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement=YES already keeps us out of the Dock; the status item is created in bootstrap.
        coordinator.bootstrap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
