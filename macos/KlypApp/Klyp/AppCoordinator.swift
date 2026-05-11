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

    init() {
        let saved = UserDefaults.standard.integer(forKey: "klyp.maxItems")
        let initialMax = saved == 0 ? 10 : saved
        let store = ClipboardStore(maxItems: initialMax)
        self.store = store
        self.watcher = PasteboardWatcher(store: store)
    }

    func bootstrap() {
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

    func paste(_ item: ClipboardItem, forceRaw: Bool = false) {
        close()
        // Wait briefly for the popover to dismiss so the keystroke goes to the previously frontmost app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [watcher] in
            let cc = Paster.paste(item, forceRaw: forceRaw)
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
