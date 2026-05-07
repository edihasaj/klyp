import AppKit
import SwiftUI

/// Owns the NSStatusItem and the popover. Done by hand (not MenuBarExtra) so
/// the global hotkey can show/hide the popover programmatically.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private weak var coordinator: AppCoordinator?
    private var transientCloseMonitor: Any?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Klyp")
            img?.isTemplate = true
            button.image = img
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: HistoryView()
                .environment(coordinator.store)
                .environment(coordinator)
        )
        popover.contentSize = NSSize(width: 360, height: 480)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(sender)
            return
        }
        toggle()
    }

    func toggle() {
        if popover.isShown {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installCloseMonitor()
    }

    func close() {
        popover.performClose(nil)
        removeCloseMonitor()
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Klyp", action: #selector(toggleFromMenu), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(withTitle: "About Klyp", action: #selector(openAbout), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Klyp", action: #selector(quit), keyEquivalent: "q")
            .target = self
        statusItem.menu = menu
        sender.performClick(nil)
        statusItem.menu = nil // restore default click behavior next time
    }

    @objc private func toggleFromMenu() { toggle() }
    @objc private func openSettings() { coordinator?.openSettings() }
    @objc private func openAbout() { coordinator?.openAbout() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// Make sure clicking outside the popover closes it even when the menu bar
    /// app isn't the active app.
    private func installCloseMonitor() {
        removeCloseMonitor()
        transientCloseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func removeCloseMonitor() {
        if let m = transientCloseMonitor {
            NSEvent.removeMonitor(m)
            transientCloseMonitor = nil
        }
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in self.removeCloseMonitor() }
    }
}
