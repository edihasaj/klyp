import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    let store: ClipboardStore
    private let watcher: PasteboardWatcher
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    /// Bundle ID of the app that was frontmost just before Klyp's popover opened.
    /// Captured because `NSApp.activate` makes Klyp itself frontmost while the
    /// popover is shown — by the time paste runs, a live lookup would return
    /// `com.edihasaj.klyp` and the trim path would miss its terminal target.
    var previousFrontmostBundleID: String?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "klyp.maxItems")
        let initialMax = saved == 0 ? 10 : saved
        let store = ClipboardStore(maxItems: initialMax)
        self.store = store
        self.watcher = PasteboardWatcher(store: store)
    }

    func bootstrap() {
        Self.logBundleHealth()
        watcher.start()
        menuBar = MenuBarController(coordinator: self)
        HotkeyManager.shared.register(
            keyCode: DefaultHotkey.keyCode,
            modifiers: DefaultHotkey.modifiers
        ) { [weak self] in
            self?.menuBar?.toggle()
        }
    }

    func close() {
        menuBar?.close()
    }

    /// Emit one diagnostic line at launch describing the running bundle's path
    /// and quarantine state. A `com.apple.quarantine` xattr on an installed
    /// Klyp.app together with a Gatekeeper rejection is what produces the
    /// "Klyp is damaged — Move to Trash" dialog on a later restart; logging it
    /// once means the next time it happens we can read the cause from Console
    /// instead of guessing.
    private static func logBundleHealth() {
        let url = Bundle.main.bundleURL
        let quarantined = (try? url.resourceValues(forKeys: [.quarantinePropertiesKey]).quarantineProperties) != nil
        NSLog("[Klyp] launched from %@ quarantine=%@", url.path, quarantined ? "yes" : "no")
    }

    func paste(_ item: ClipboardItem, forceRaw: Bool = false) {
        let targetBundleID = previousFrontmostBundleID
        close()
        // Wait briefly for the popover to dismiss so the keystroke goes to the previously frontmost app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [watcher] in
            let cc = Paster.paste(item, forceRaw: forceRaw, targetBundleID: targetBundleID)
            watcher.ignoreNextChangeCount = cc + 1
        }
    }

    func openSettings() {
        close()
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: SettingsView().environment(store))
        let win = NSWindow(contentViewController: host)
        win.title = "Klyp Settings"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.center()
        settingsWindow = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    func openAbout() {
        close()
        if let win = aboutWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: AboutView().frame(width: 320, height: 320))
        let win = NSWindow(contentViewController: host)
        win.title = "About Klyp"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        aboutWindow = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
