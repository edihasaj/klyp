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
    private var buttonTrackingArea: NSTrackingArea?
    private var isButtonHovered = false
    private var isButtonPressed = false
    private var clickFeedbackWorkItem: DispatchWorkItem?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = Self.menuBarIcon(active: false)
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.wantsLayer = true
            installButtonTracking(on: button)
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
        flashClickFeedback(on: sender)
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
        // Snapshot the app that's frontmost *before* we activate Klyp — paste
        // time uses this to decide whether the target app is a terminal.
        let prior = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if prior != Bundle.main.bundleIdentifier {
            coordinator?.previousFrontmostBundleID = prior
        }
        NSApp.activate(ignoringOtherApps: true)
        updateStatusButtonImage()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installCloseMonitor()
    }

    func close() {
        popover.performClose(nil)
        removeCloseMonitor()
    }

    /// Stack-of-cards mark, drawn programmatically so it can switch between a
    /// menu-bar template (auto-tints to white in dark menu bar / black in light)
    /// and a brand-pink "active" version when the popover is showing.
    static func menuBarIcon(active: Bool, hovered: Bool = false, pressed: Bool = false) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = size
            let cardW = s * 0.62
            let cardH = s * 0.74
            let cx = s / 2
            let cy = s / 2
            let corner = s * 0.13

            let activeColor = CGColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 1.0)
            let hoverColor = CGColor(red: 1.0, green: 0.52, blue: 0.70, alpha: 1.0)
            let pressedColor = CGColor(red: 1.0, green: 0.72, blue: 0.82, alpha: 1.0)
            let tintColor = pressed ? pressedColor : (active ? activeColor : hoverColor)
            let opacityScale: CGFloat = pressed ? 1.0 : (active ? 1.0 : 0.72)
            let layers: [(dx: CGFloat, dy: CGFloat, alpha: CGFloat)] = [
                (-s * 0.10, -s * 0.10, 0.45),
                (0, 0, 0.75),
                (s * 0.10, s * 0.10, 1.00),
            ]

            for layer in layers {
                let rect = CGRect(
                    x: cx - cardW / 2 + layer.dx,
                    y: cy - cardH / 2 + layer.dy,
                    width: cardW, height: cardH
                )
                if active || hovered || pressed {
                    var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
                    NSColor(cgColor: tintColor)?.getRed(&r, green: &g, blue: &b, alpha: &a)
                    ctx.setFillColor(red: r, green: g, blue: b, alpha: layer.alpha * opacityScale)
                } else {
                    ctx.setFillColor(CGColor(gray: 0, alpha: layer.alpha))
                }
                ctx.addPath(CGPath(
                    roundedRect: rect,
                    cornerWidth: corner, cornerHeight: corner, transform: nil
                ))
                ctx.fillPath()
            }
            return true
        }
        image.isTemplate = !(active || hovered || pressed)
        return image
    }

    private func installButtonTracking(on button: NSStatusBarButton) {
        if let buttonTrackingArea {
            button.removeTrackingArea(buttonTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(area)
        buttonTrackingArea = area
    }

    @objc func mouseEntered(with event: NSEvent) {
        isButtonHovered = true
        updateStatusButtonImage()
    }

    @objc func mouseExited(with event: NSEvent) {
        isButtonHovered = false
        updateStatusButtonImage()
    }

    private func flashClickFeedback(on button: NSStatusBarButton) {
        clickFeedbackWorkItem?.cancel()
        isButtonPressed = true
        updateStatusButtonImage()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.07
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.animator().alphaValue = 0.58
        } completionHandler: {
            Task { @MainActor in
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.12
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    button.animator().alphaValue = 1.0
                }
            }
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.isButtonPressed = false
            self?.updateStatusButtonImage()
        }
        clickFeedbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
    }

    private func updateStatusButtonImage() {
        statusItem.button?.image = Self.menuBarIcon(
            active: popover.isShown,
            hovered: isButtonHovered,
            pressed: isButtonPressed
        )
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
        Task { @MainActor in
            self.removeCloseMonitor()
            self.updateStatusButtonImage()
        }
    }
}
