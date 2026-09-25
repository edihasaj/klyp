import AppKit
import Foundation

/// How a stored item is transformed on its way back to the pasteboard.
enum PasteMode: Sendable {
    /// Heuristic clean-up per the user's trim settings (plain ↵ / click).
    case smart
    /// Deterministic clean-up — always strips gutters/indent and rejoins
    /// terminal soft-wraps, ignoring trim settings (⇧↵).
    case plain
    /// Same characters, no styling: rich text is dropped so the paste picks up
    /// the destination's own font/color instead of carrying the source's
    /// highlight background (⌃↵ in the popover, ⌃⇧V globally).
    case unstyled
    /// Byte-for-byte what was copied (⌥↵ / "Paste Original").
    case original
}

@MainActor
enum Paster {
    /// Place item back on the pasteboard and synthesize a ⌘V keystroke into the
    /// frontmost app. Returns the new pasteboard changeCount so the watcher can
    /// ignore its own write.
    ///
    /// `targetBundleID` is the bundle ID of the app the paste will land in,
    /// captured before Klyp activated itself. Falls back to a live lookup
    /// when omitted (e.g. unit tests).
    @discardableResult
    static func paste(
        _ item: ClipboardItem,
        mode: PasteMode = .smart,
        targetBundleID: String? = nil,
        sendKey: Bool = true
    ) -> Int {
        let effective: ClipboardItem = switch mode {
        case .original: item
        case .plain: plainText(item)
        case .unstyled: unstyled(item)
        case .smart: applyTrim(item, targetBundleID: targetBundleID)
        }
        writeToPasteboard(effective)
        let cc = NSPasteboard.general.changeCount
        if sendKey { synthesizeCommandV() }
        return cc
    }

    /// Deterministic normalization for the "Paste as Plain Text" mode. Runs
    /// regardless of trim settings or which app is on either end, and drops
    /// rich-text data so the paste lands as unstyled text.
    static func plainText(_ item: ClipboardItem) -> ClipboardItem {
        guard item.kind != .image, item.kind != .files, !item.text.isEmpty else { return item }
        let text = PlainTextNormalizer.normalize(item.text)
        guard text != item.text || item.kind != .text else { return item }
        return ClipboardItem(
            id: item.id,
            kind: .text,
            createdAt: item.createdAt,
            text: text,
            rtfData: nil,
            imageFilename: item.imageFilename,
            filePaths: item.filePaths,
            hash: item.hash,
            pinned: item.pinned,
            sourceBundleID: item.sourceBundleID
        )
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

    /// Strips styling without touching the characters. VS Code (and any editor
    /// that offers RTF/HTML flavors) copies syntax colors and a highlight
    /// background along with the code; dropping the rich-text payload makes the
    /// paste adopt the destination's formatting instead.
    static func unstyled(_ item: ClipboardItem) -> ClipboardItem {
        guard item.kind == .richText || item.kind == .url else { return item }
        guard !item.text.isEmpty else { return item }
        return ClipboardItem(
            id: item.id,
            kind: .text,
            createdAt: item.createdAt,
            text: item.text,
            rtfData: nil,
            imageFilename: item.imageFilename,
            filePaths: item.filePaths,
            hash: item.hash,
            pinned: item.pinned,
            sourceBundleID: item.sourceBundleID
        )
    }

    /// Runs `body` once no modifier keys are physically held (or after a short
    /// timeout). Synthesizing ⌘V while the user still holds ⌃⇧ from the hotkey
    /// would reach the target app as ⌃⇧⌘V and do nothing — or worse, trigger
    /// some other shortcut.
    static func whenModifiersReleased(
        timeout: TimeInterval = 0.6,
        pollInterval: TimeInterval = 0.02,
        _ body: @escaping () -> Void
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        func poll() {
            let held = NSEvent.modifierFlags
                .intersection([.control, .shift, .option, .command])
            if held.isEmpty || Date() >= deadline {
                body()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { poll() }
        }
        poll()
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
