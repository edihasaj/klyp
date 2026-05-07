import AppKit
import CryptoKit
import Foundation

@MainActor
final class PasteboardWatcher {
    private weak var store: ClipboardStore?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    /// When Klyp itself writes to the pasteboard (paste-back), we bump this so the next change is ignored.
    var ignoreNextChangeCount: Int = -1

    init(store: ClipboardStore) {
        self.store = store
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        let t = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let cc = pasteboard.changeCount
        guard cc != lastChangeCount else { return }
        if cc == ignoreNextChangeCount {
            lastChangeCount = cc
            return
        }
        if let item = readCurrent() {
            lastChangeCount = cc
            store?.insert(item)
            emptyReadAttempts = 0
            return
        }
        // Pasteboard is in a transient state (e.g. between clearContents and
        // writeObjects, or the writer used promised data and exited). Don't
        // advance lastChangeCount yet — try again on the next poll. After a
        // few unsuccessful retries, give up to avoid spinning.
        emptyReadAttempts += 1
        if emptyReadAttempts > 3 {
            lastChangeCount = cc
            emptyReadAttempts = 0
        }
    }
    private var emptyReadAttempts: Int = 0

    private func readCurrent() -> ClipboardItem? {
        let types = pasteboard.types ?? []

        // 1. File URLs (videos, PDFs, anything dragged from Finder).
        if types.contains(.fileURL) {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
                let paths = urls.map(\.path)
                let caption = paths.count == 1
                    ? (paths[0] as NSString).lastPathComponent
                    : "\(paths.count) files"
                let hash = sha("files:" + paths.joined(separator: "\u{1F}"))
                return .files(paths, caption: caption, hash: hash)
            }
        }

        // 2. Image (PNG / TIFF). Cache to disk so it survives relaunch.
        if types.contains(.png) || types.contains(.tiff) {
            if let data = pasteboard.data(forType: .png) ?? imagePNGFromTIFF() {
                let hash = sha("img:" + sha(data))
                let filename = "\(hash).png"
                let url = AppPaths.imageCacheDir.appendingPathComponent(filename)
                if !FileManager.default.fileExists(atPath: url.path) {
                    try? data.write(to: url)
                }
                let caption = "Image"
                return .image(filename: filename, caption: caption, hash: hash)
            }
        }

        // 3. RTF rich text — keep both plain and rtf payloads.
        if types.contains(.rtf), let rtf = pasteboard.data(forType: .rtf) {
            let plain = pasteboard.string(forType: .string) ?? ""
            if !plain.isEmpty || !rtf.isEmpty {
                let hash = sha("rtf:" + sha(rtf))
                return .richText(plain: plain, rtf: rtf, hash: hash)
            }
        }

        // 4. URL — cleaner display than raw text.
        if types.contains(.URL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let first = urls.first {
            let s = first.absoluteString
            return .url(s, hash: sha("url:" + s))
        }

        // 5. Plain text (last because most types include it as fallback).
        if let s = pasteboard.string(forType: .string) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .text(s, hash: sha("text:" + s))
        }

        return nil
    }

    private func imagePNGFromTIFF() -> Data? {
        guard let tiff = pasteboard.data(forType: .tiff),
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func sha(_ s: String) -> String {
        sha(Data(s.utf8))
    }

    private func sha(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
