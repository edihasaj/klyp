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

    func register(keyCode: UInt32, modifiers: UInt32, onFire: @escaping () -> Void) {
        unregister()
        self.onFire = onFire

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

        let hkID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let h = eventHandler { RemoveEventHandler(h); eventHandler = nil }
        onFire = nil
    }
}

enum DefaultHotkey {
    /// kVK_ANSI_V = 9, paired with ⇧⌘ matches CopyClip's default.
    static let keyCode: UInt32 = 9
    static let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
}
