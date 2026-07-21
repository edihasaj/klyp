import AppKit
import Carbon.HIToolbox
import Foundation

/// One global shortcut Klyp wants to own.
struct HotkeyBinding: Sendable, Equatable {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    /// Human-readable form, for logs only.
    let label: String
}

/// Registers Klyp's global hotkeys using the Carbon Event Manager. Carbon is
/// deprecated for many things, but `RegisterEventHotKey` remains the supported
/// way to claim a system-wide shortcut on macOS as of 14+.
///
/// Registration is treated as something that can be *lost*, not just fail at
/// launch: a hotkey can be stolen by another app that starts later, and a
/// long-lived login session (sleep/wake, fast user switching, display sleep)
/// can leave Klyp holding a ref that no longer fires. Both failure modes look
/// identical to the user — the shortcut silently does nothing — so we retry
/// indefinitely on a capped back-off and force a clean re-registration on wake
/// and on screen unlock.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private let signature: OSType = 0x4B4C5950 // 'KLYP'
    private var eventHandler: EventHandlerRef?
    private var bindings: [UInt32: HotkeyBinding] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var retryAttempts: [UInt32: Int] = [:]
    private var observersInstalled = false

    /// Longest gap between retries. We never give up — an app that stole the
    /// shortcut may quit hours later, and the user shouldn't have to restart
    /// Klyp to get it back.
    private static let maxRetryDelay: Double = 60

    func register(_ binding: HotkeyBinding, onFire: @escaping () -> Void) {
        installEventHandlerIfNeeded()
        installSystemObserversIfNeeded()
        bindings[binding.id] = binding
        handlers[binding.id] = onFire
        retryAttempts[binding.id] = 0
        tryRegister(binding.id)
    }

    /// Drop and re-claim every binding. Used after wake/unlock, where a ref can
    /// survive as a non-nil pointer that no longer delivers events.
    func reregisterAll() {
        for id in bindings.keys {
            unregister(id)
            retryAttempts[id] = 0
            tryRegister(id)
        }
    }

    func unregisterAll() {
        for id in bindings.keys { unregister(id) }
        if let h = eventHandler { RemoveEventHandler(h); eventHandler = nil }
        bindings.removeAll()
        handlers.removeAll()
    }

    // MARK: - Registration

    private func tryRegister(_ id: UInt32) {
        guard let binding = bindings[id] else { return }
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            binding.keyCode, binding.modifiers, hkID, GetApplicationEventTarget(), 0, &ref
        )
        let attempt = (retryAttempts[id] ?? 0) + 1
        if status == noErr {
            refs[id] = ref
            retryAttempts[id] = 0
            NSLog("[Klyp] Hotkey %@ registered (attempt %d)", binding.label, attempt)
            return
        }
        retryAttempts[id] = attempt
        NSLog("[Klyp] RegisterEventHotKey %@ failed status=%d attempt=%d — retrying",
              binding.label, status, attempt)
        let delay = min(pow(2.0, Double(attempt)), Self.maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.refs[id] == nil else { return }
            self.tryRegister(id)
        }
    }

    private func unregister(_ id: UInt32) {
        if let ref = refs[id] {
            UnregisterEventHotKey(ref)
            refs[id] = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            let id = hkID.id
            DispatchQueue.main.async { manager.fire(id) }
            return noErr
        }, 1, &spec, userData, &eventHandler)
    }

    private func fire(_ id: UInt32) {
        handlers[id]?()
    }

    // MARK: - Self-healing

    private func installSystemObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reregisterAll() }
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reregisterAll() }
        }
    }
}

enum DefaultHotkey {
    /// kVK_Space = 49, paired with ⌃ for an unobtrusive trigger that doesn't
    /// stomp on editors' ⇧⌘V (paste-and-match-style).
    static let toggle = HotkeyBinding(
        id: 1, keyCode: 49, modifiers: UInt32(controlKey), label: "⌃Space"
    )

    /// kVK_ANSI_V = 9. Pastes the newest item with every trace of styling
    /// removed — the system's own ⌥⇧⌘V is honoured by too few apps to rely on.
    static let pasteUnstyled = HotkeyBinding(
        id: 2, keyCode: 9, modifiers: UInt32(controlKey | shiftKey), label: "⌃⇧V"
    )
}
