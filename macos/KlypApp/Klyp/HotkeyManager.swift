import AppKit
import Carbon.HIToolbox
import Foundation

/// Registers a single global hotkey using the Carbon Event Manager. Carbon is
/// deprecated for many things, but `RegisterEventHotKey` remains the supported
/// way to claim a system-wide shortcut on macOS as of 14+.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onFire: (() -> Void)?
    private let signature: OSType = 0x4B4C5950 // 'KLYP'
    private var pendingKeyCode: UInt32?
    private var pendingModifiers: UInt32?
    private var retryAttempts = 0
    private static let maxRetryAttempts = 5

    func register(keyCode: UInt32, modifiers: UInt32, onFire: @escaping () -> Void) {
        unregister()
        self.onFire = onFire
        self.pendingKeyCode = keyCode
        self.pendingModifiers = modifiers
        self.retryAttempts = 0

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            DispatchQueue.main.async { manager.onFire?() }
            return noErr
        }, 1, &spec, userData, &eventHandler)

        tryRegister()
    }

    /// On a fresh login another process (input-source switcher, Spotlight,
    /// Raycast/Alfred) can still own ⌃Space when Klyp launches, in which case
    /// `RegisterEventHotKey` returns `eventHotKeyExistsErr` (-9878) and our
    /// shortcut silently does nothing. Retry on a back-off — system services
    /// usually settle within a few seconds — and log the final state.
    private func tryRegister() {
        guard let keyCode = pendingKeyCode, let modifiers = pendingModifiers else { return }
        let hkID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            NSLog("[Klyp] Hotkey registered (attempt %d)", retryAttempts + 1)
            return
        }
        retryAttempts += 1
        NSLog("[Klyp] RegisterEventHotKey failed status=%d attempt=%d", status, retryAttempts)
        guard retryAttempts < Self.maxRetryAttempts else {
            NSLog("[Klyp] Giving up on hotkey registration — another app likely owns ⌃Space")
            return
        }
        let delay = pow(2.0, Double(retryAttempts)) // 2, 4, 8, 16, 32 s
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.tryRegister()
        }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let h = eventHandler { RemoveEventHandler(h); eventHandler = nil }
        onFire = nil
    }
}

enum DefaultHotkey {
    /// kVK_Space = 49, paired with ⌃ for an unobtrusive trigger that doesn't
    /// stomp on editors' ⇧⌘V (paste-and-match-style).
    static let keyCode: UInt32 = 49
    static let modifiers: UInt32 = UInt32(controlKey)
}
