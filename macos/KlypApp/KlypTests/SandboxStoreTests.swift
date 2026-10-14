#if MAC_APP_STORE
import AppKit
import Security
import SwiftUI
import XCTest
@testable import Klyp

final class SandboxStoreTests: XCTestCase {
    @MainActor
    func testSignedSandboxHistoryAndClipboard() throws {
        var code: SecCode?
        XCTAssertEqual(SecCodeCopySelf([], &code), errSecSuccess)
        var staticCode: SecStaticCode?
        XCTAssertEqual(SecCodeCopyStaticCode(try XCTUnwrap(code), [], &staticCode), errSecSuccess)
        var information: CFDictionary?
        XCTAssertEqual(SecCodeCopySigningInformation(try XCTUnwrap(staticCode),
            SecCSFlags(rawValue: kSecCSSigningInformation), &information), errSecSuccess)
        let details = try XCTUnwrap(information as? [String: Any])
        let entitlements = try XCTUnwrap(details[kSecCodeInfoEntitlementsDict as String] as? [String: Any])
        XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertTrue(AppPaths.supportDir.path.contains("/Containers/com.edihasaj.klyp/"))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ClipboardStore(maxItems: 5, fileURL: file)
        let text = ClipboardItem.text("Klyp sandbox clipboard verification", hash: UUID().uuidString)
        store.insert(text)
        store.togglePin(id: text.id)
        store.waitForPendingPersist()
        let reopened = ClipboardStore(maxItems: 5, fileURL: file)
        XCTAssertEqual(reopened.items.first?.text, text.text)
        XCTAssertEqual(reopened.items.first?.pinned, true)
        Paster.paste(text, mode: .original, sendKey: false)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), text.text)
        let rtf = try NSAttributedString(string: "Unstyled text").data(
            from: NSRange(location: 0, length: 13), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        Paster.paste(.richText(plain: "Unstyled text", rtf: rtf, hash: UUID().uuidString),
                     mode: .unstyled, sendKey: false)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Unstyled text")
        XCTAssertNil(NSPasteboard.general.data(forType: .rtf))
        HotkeyManager.shared.register(DefaultHotkey.toggle) {}
        HotkeyManager.shared.reregisterAll()
        HotkeyManager.shared.unregisterAll()
        print("Verified signed sandbox, durable history, clipboard restoration, and Carbon registration.")
        print("Accessibility trust during verification: \(AXIsProcessTrusted())")
    }

    @MainActor
    func testNativeStoreScreenshots() async throws {
        let coordinator = AppCoordinator()
        let store = ClipboardStore(maxItems: 10, fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
        let samples = [
            ClipboardItem.text("A small idea worth keeping.", hash: "store-shot-note"),
            ClipboardItem.url("https://github.com/edihasaj/klyp", hash: "store-shot-url"),
            ClipboardItem.text("swift build \\\n  --configuration release", hash: "store-shot-command"),
            ClipboardItem.text("Your next copy is never far away.", hash: "store-shot-copy"),
        ]
        for item in samples { store.insert(item) }
        store.togglePin(id: samples[0].id)
        try await capture(HistoryView().environment(store).environment(coordinator),
                          name: "01-history", size: NSSize(width: 360, height: 480))
        try await capture(SettingsView().environment(store),
                          name: "02-settings", size: NSSize(width: 460, height: 380))
    }

    @MainActor
    private func capture<V: View>(_ view: V, name: String, size: NSSize) async throws {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentView = host
        window.title = "Klyp"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(800))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        window.orderOut(nil)
    }
}
#endif
