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
    private var pendingClickPaste: DispatchWorkItem?
    private var pendingClickGeneration = 0

    /// Bundle ID of the app that was frontmost just before Klyp's popover opened.
    /// Captured because `NSApp.activate` makes Klyp itself frontmost while the
    /// popover is shown — by the time paste runs, a live lookup would return
    /// `com.edihasaj.klyp` and the trim path would miss its terminal target.
    var previousFrontmostBundleID: String?
    var previousFrontmostApplication: NSRunningApplication?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "klyp.maxItems")
        let initialMax = saved == 0 ? 10 : saved
        let store = ClipboardStore(maxItems: initialMax)
        self.store = store
        self.watcher = PasteboardWatcher(store: store)
    }

    func bootstrap() {
        Self.logBundleHealth()
        LoginItem.seedFirstRunIfNeeded()
        watcher.start()
        menuBar = MenuBarController(coordinator: self)
        HotkeyManager.shared.register(DefaultHotkey.toggle) { [weak self] in
            self?.menuBar?.toggleAtCursor()
        }
        HotkeyManager.shared.register(DefaultHotkey.pasteUnstyled) { [weak self] in
            self?.pasteLatestUnstyled()
        }
        // XCTest hosts the app too, but its runner cannot answer a modal alert.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.menuBar?.offerAccessibilityIfNeeded()
            }
        }
    }

    /// ⌃⇧V — paste the newest clipboard item into the frontmost app with all
    /// styling stripped (no fonts, colors or highlight backgrounds), without
    /// opening the popover. Text content itself is untouched.
    func pasteLatestUnstyled() {
        guard let item = store.items.max(by: { $0.createdAt < $1.createdAt }) else { return }
        // Klyp never activated, so the frontmost app is already the target.
        Paster.whenModifiersReleased { [watcher] in
            let cc = Paster.paste(item, mode: .unstyled)
            watcher.ignoreNextChangeCount = cc + 1
        }
    }

    func close() {
        menuBar?.close()
    }

    /// Keep the chosen item alive even if macOS dismisses the popover while
    /// SwiftUI is showing its pressed feedback.
    func scheduleClickPaste(_ item: ClipboardItem, mode: PasteMode) {
        pendingClickPaste?.cancel()
        pendingClickGeneration += 1
        let generation = pendingClickGeneration
        NSLog("[Klyp] Picker click queued")
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pendingClickGeneration == generation else { return }
            self.pendingClickPaste = nil
            NSLog("[Klyp] Picker click committed")
            self.paste(item, mode: mode)
        }
        pendingClickPaste = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    func cancelPendingClickPaste() {
        pendingClickPaste?.cancel()
        pendingClickPaste = nil
        pendingClickGeneration += 1
    }

    func openAccessibilitySettings() {
        close()
        HotkeyManager.shared.requestAccessibilityIfNeeded()
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
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

    func paste(_ item: ClipboardItem, mode: PasteMode = .smart) {
        let targetBundleID = previousFrontmostBundleID
        let targetApplication = previousFrontmostApplication
        close()
        if let targetApplication, !targetApplication.isTerminated {
            targetApplication.activate(options: [])
        }
        pasteWhenTargetIsReady(item, mode: mode, targetBundleID: targetBundleID,
                               targetApplication: targetApplication, attemptsRemaining: 20)
    }

    private func pasteWhenTargetIsReady(
        _ item: ClipboardItem,
        mode: PasteMode,
        targetBundleID: String?,
        targetApplication: NSRunningApplication?,
        attemptsRemaining: Int
    ) {
        let isReady = targetApplication.map {
            NSWorkspace.shared.frontmostApplication?.processIdentifier == $0.processIdentifier
        } ?? false
        if !isReady && targetApplication != nil && attemptsRemaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.pasteWhenTargetIsReady(item, mode: mode, targetBundleID: targetBundleID,
                                             targetApplication: targetApplication,
                                             attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }
        if !isReady {
            NSLog("[Klyp] Paste target did not become frontmost; copied item without sending keys")
        } else {
            NSLog("[Klyp] Paste target is frontmost; sending Command-V")
        }
        let cc = Paster.paste(item, mode: mode, targetBundleID: targetBundleID,
                              sendKey: isReady)
        watcher.ignoreNextChangeCount = cc + 1
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
