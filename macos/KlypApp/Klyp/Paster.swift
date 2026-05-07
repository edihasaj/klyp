import AppKit
import Foundation

@MainActor
enum Paster {
    /// Place item back on the pasteboard and synthesize a ⌘V keystroke into the
    /// frontmost app. Returns the new pasteboard changeCount so the watcher can
    /// ignore its own write.
    @discardableResult
    static func paste(_ item: ClipboardItem) -> Int {
        writeToPasteboard(item)
        let cc = NSPasteboard.general.changeCount
        synthesizeCommandV()
        return cc
    }

    static func writeToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text:
            pb.setString(item.text, forType: .string)
        case .url:
            if let url = URL(string: item.text) {
                pb.writeObjects([url as NSURL])
            } else {
                pb.setString(item.text, forType: .string)
            }
        case .richText:
            if let rtf = item.rtfData {
                pb.setData(rtf, forType: .rtf)
            }
            if !item.text.isEmpty {
                pb.setString(item.text, forType: .string)
            }
        case .image:
            if let filename = item.imageFilename {
                let url = AppPaths.imageCacheDir.appendingPathComponent(filename)
                if let data = try? Data(contentsOf: url) {
                    pb.setData(data, forType: .png)
                    if let img = NSImage(data: data) {
                        pb.writeObjects([img])
                    }
                }
            }
        case .files:
            if let paths = item.filePaths {
                let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        }
    }

    private static func synthesizeCommandV() {
        // Requires Accessibility permission (System Settings → Privacy → Accessibility).
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
