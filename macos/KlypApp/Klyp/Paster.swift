import AppKit
import Foundation

@MainActor
enum Paster {
    /// Place item back on the pasteboard and synthesize a ⌘V keystroke into the
    /// frontmost app. Returns the new pasteboard changeCount so the watcher can
    /// ignore its own write.
    ///
    /// `forceRaw` skips smart-trim even when settings would apply it (used by
    /// the ⌥-held paste and the "Paste Original" context menu item).
    /// `targetBundleID` is the bundle ID of the app the paste will land in,
    /// captured before Klyp activated itself. Falls back to a live lookup
    /// when omitted (e.g. unit tests).
    @discardableResult
    static func paste(_ item: ClipboardItem, forceRaw: Bool = false, targetBundleID: String? = nil) -> Int {
        let effective = forceRaw ? item : applyTrim(item, targetBundleID: targetBundleID)
        writeToPasteboard(effective)
        let cc = NSPasteboard.general.changeCount
        synthesizeCommandV()
        return cc
    }

    /// If the item is text and the user's trim settings apply to the target
    /// app, return a new item with flattened text. Otherwise the original is
    /// returned unchanged.
    static func applyTrim(_ item: ClipboardItem, targetBundleID: String? = nil) -> ClipboardItem {
        guard item.kind == .text else { return item }
        let settings = TrimSettings.load()
        let bundleID = targetBundleID ?? TerminalApps.frontmostBundleID()
        let isTermTarget = TerminalApps.isTerminal(bundleID: bundleID)
        let isTermSource = TerminalApps.isTerminal(bundleID: item.sourceBundleID)
        let level = settings.aggressiveness(forTerminal: isTermTarget)
        // Markdown extraction is terminal-only — stripping fences/indent from a
        // paste into TextEdit or a chat box would destroy formatting the user
        // wanted.
        let extracted = (settings.extractMarkdown && isTermTarget)
            ? MarkdownExtractor.extract(item.text)
            : nil

        // Terminal-source cleanup runs when the source app was a terminal
        // and the user has terminal trim enabled (master toggle on, terminal
        // level not .off). Gutter glyphs and soft-wrap newlines from a
        // narrow Ghostty window are unwanted in any paste target — but
        // skipped when pasting back into a terminal, since the user pulled
        // multi-line content out for a reason and re-flattening it on
        // re-entry would be surprising.
        let runTerminalUnwrap = settings.enabled
            && settings.terminalLevel != .off
            && isTermSource
            && !isTermTarget

        guard level != .off || extracted != nil || runTerminalUnwrap else { return item }

        var text = extracted ?? item.text
        if level != .off {
            let trimmer = CommandTrimmer(
                aggressiveness: level,
                preserveBlankLines: settings.preserveBlankLines,
                removeBoxDrawing: settings.removeBoxDrawing
            )
            if let flat = trimmer.transformIfCommand(text) {
                text = flat
            }
        }
        if runTerminalUnwrap {
            if let stripped = TUIGutterStripper().stripIfGuttered(text) {
                text = stripped
            }
            if let collapsed = SoftWrapCollapser().collapseIfSoftWrapped(text) {
                text = collapsed
            }
        }
        guard text != item.text else { return item }

        return ClipboardItem(
            id: item.id,
            kind: item.kind,
            createdAt: item.createdAt,
            text: text,
            rtfData: item.rtfData,
            imageFilename: item.imageFilename,
            filePaths: item.filePaths,
            hash: item.hash,
            pinned: item.pinned,
            sourceBundleID: item.sourceBundleID
        )
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
