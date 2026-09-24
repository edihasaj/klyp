import AppKit
import SwiftUI

/// Presents history from the menu bar or beside the pointer for the hotkey.
@MainActor
final class MenuBarController: NSResponder, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let cursorAnchorWindow: NSWindow
    private let cursorAnchorView: NSView
    private weak var coordinator: AppCoordinator?
    private var previousFrontmostApplication: NSRunningApplication?
    private var openedAtCursor = false
    private var transientCloseMonitor: Any?
    private var buttonTrackingArea: NSTrackingArea?
    private var isButtonHovered = false
    private var isButtonPressed = false
    private var clickFeedbackWorkItem: DispatchWorkItem?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.cursorAnchorView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        self.cursorAnchorWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
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

        cursorAnchorWindow.contentView = cursorAnchorView
        cursorAnchorWindow.isOpaque = false
        cursorAnchorWindow.backgroundColor = .clear
        cursorAnchorWindow.alphaValue = 0.01
        cursorAnchorWindow.ignoresMouseEvents = true
        cursorAnchorWindow.level = .floating
        cursorAnchorWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    }

    required init?(coder: NSCoder) {
        fatalError("MenuBarController must be initialized with an AppCoordinator")
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(sender)
            return
        }
        flashClickFeedback(on: sender)
        toggleMenuBar()
    }

    func toggleMenuBar() {
        if popover.isShown {
            close()
        } else {
            close()
            showMenuBar()
        }
    }

    func toggleAtCursor() {
        if popover.isShown {
            close()
        } else {
            showAtCursor()
        }
    }

    private func rememberFrontmostApp() {
        let prior = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if prior != Bundle.main.bundleIdentifier {
            coordinator?.previousFrontmostBundleID = prior
            previousFrontmostApplication = NSWorkspace.shared.frontmostApplication
        }
    }

    private func showMenuBar() {
        guard let button = statusItem.button else { return }
        // Snapshot the app that's frontmost *before* we activate Klyp — paste
        // time uses this to decide whether the target app is a terminal.
        rememberFrontmostApp()
        openedAtCursor = false
        refreshHistoryView()
        NSApp.activate(ignoringOtherApps: true)
        updateStatusButtonImage()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installCloseMonitor()
    }

    private func showAtCursor() {
        rememberFrontmostApp()
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let screen else { return }
        cursorAnchorWindow.setFrameOrigin(Self.anchorOrigin(near: pointer, visibleFrame: screen.visibleFrame))
        cursorAnchorWindow.orderFrontRegardless()
        openedAtCursor = true
        refreshHistoryView()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: cursorAnchorView.bounds, of: cursorAnchorView, preferredEdge: .minY)
        updateStatusButtonImage()
        installCloseMonitor()
    }

    func close() {
        let wasOpenedAtCursor = openedAtCursor
        openedAtCursor = false
        popover.performClose(nil)
        cursorAnchorWindow.orderOut(nil)
        removeCloseMonitor()
        updateStatusButtonImage()
        if wasOpenedAtCursor,
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            previousFrontmostApplication?.activate(options: [])
        }
    }

    static func anchorOrigin(near pointer: NSPoint, visibleFrame: NSRect) -> NSPoint {
        let gap: CGFloat = 12
        return NSPoint(
            x: min(max(pointer.x + gap, visibleFrame.minX), visibleFrame.maxX - 1),
            y: min(max(pointer.y - gap, visibleFrame.minY), visibleFrame.maxY - 1)
        )
    }

    private func refreshHistoryView() {
        guard let coordinator else { return }
        popover.contentViewController = NSHostingController(
            rootView: HistoryView()
                .environment(coordinator.store)
                .environment(coordinator)
        )
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

    override func mouseEntered(with event: NSEvent) {
        isButtonHovered = true
        updateStatusButtonImage()
    }

    override func mouseExited(with event: NSEvent) {
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
        if !AXIsProcessTrusted() {
            menu.addItem(withTitle: "Enable Accessibility…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
                .target = self
            menu.addItem(.separator())
        }
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

    func offerAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let key = "klyp.accessibilityOfferVersion"
        guard UserDefaults.standard.string(forKey: key) != version else { return }
        UserDefaults.standard.set(version, forKey: key)
        showMenuBar()
    }

    @objc private func toggleFromMenu() { toggleMenuBar() }
    @objc private func openAccessibilitySettings() { coordinator?.openAccessibilitySettings() }
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
            guard !self.popover.isShown else { return }
            self.openedAtCursor = false
            self.cursorAnchorWindow.orderOut(nil)
            self.removeCloseMonitor()
            self.updateStatusButtonImage()
        }
    }
}
