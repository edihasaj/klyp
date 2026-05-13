import Foundation

/// Collapses terminal soft-wrap newlines back into spaces.
///
/// When a terminal window is narrow, copying a long message inserts hard
/// `\n` at the wrap column. Pasting elsewhere keeps those breaks, which is
/// almost never what the user wanted. This collapser detects runs of
/// consecutive lines that look wrapped (similar widths, no list/code/prompt
/// markers) and joins them with a single space, while preserving real
/// paragraph breaks (blank lines).
///
/// Conservative by design — it only runs when the source app was a terminal,
/// and bails out on any structural signal that the newlines might be
/// intentional (code fences, prompts, bullets, command flags).
struct SoftWrapCollapser: Sendable {
    /// Minimum length for a line to count as "wrap-saturated". Lines shorter
    /// than this in the middle of a run almost certainly ended on purpose.
    let minWrapWidth: Int
    /// Maximum allowed spread between the longest and shortest non-final line
    /// in a soft-wrap run. Real wraps cluster within a few chars of each other.
    let widthTolerance: Int

    init(minWrapWidth: Int = 30, widthTolerance: Int = 8) {
        self.minWrapWidth = minWrapWidth
        self.widthTolerance = widthTolerance
    }

    /// Returns the collapsed form, or nil if the input doesn't look like
    /// it has soft-wrapped runs worth touching.
    func collapseIfSoftWrapped(_ input: String) -> String? {
        guard !input.isEmpty else { return nil }
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else { return nil }

        // Whole-input gates: never touch text that has any structural signal.
        if lines.contains(where: { isStructuralLine($0) }) { return nil }

        var out: [String] = []
        var i = 0
        var collapsedAnything = false

        while i < lines.count {
            let line = lines[i]
            // Blank lines are paragraph separators — emit verbatim.
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                out.append(line)
                i += 1
                continue
            }

            // Gather a run of consecutive non-blank lines.
            var runEnd = i
            while runEnd < lines.count
                && !lines[runEnd].trimmingCharacters(in: .whitespaces).isEmpty {
                runEnd += 1
            }
            let run = Array(lines[i..<runEnd])

            if shouldCollapseRun(run) {
                out.append(joinRun(run))
                collapsedAnything = true
            } else {
                out.append(contentsOf: run)
            }
            i = runEnd
        }

        guard collapsedAnything else { return nil }
        let joined = out.joined(separator: "\n")
        return joined == input ? nil : joined
    }

    // MARK: - Run-level decisions

    private func shouldCollapseRun(_ run: [String]) -> Bool {
        guard run.count >= 2 else { return false }
        // The last line in a run is naturally short (it's where the message
        // ends). Only the *non-final* lines need to look wrap-saturated.
        let leading = run.dropLast()
        let widths = leading.map { displayWidth($0) }
        guard let minW = widths.min(), let maxW = widths.max() else { return false }
        guard minW >= minWrapWidth else { return false }
        guard maxW - minW <= widthTolerance else { return false }
        return true
    }

    private func joinRun(_ run: [String]) -> String {
        // Collapse interior whitespace runs to single spaces while joining,
        // and drop any trailing/leading whitespace each line picked up at the
        // wrap boundary.
        var pieces: [String] = []
        for line in run {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { pieces.append(trimmed) }
        }
        return pieces.joined(separator: " ")
    }

    // MARK: - Structural signals

    /// Lines that suggest the newline was intentional. If any line in the
    /// input matches, the whole input is left alone — collapsing across a
    /// bullet or fenced block would corrupt it.
    private func isStructuralLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return false }
        // Code fence.
        if t.hasPrefix("```") { return true }
        // Bullet or ordered-list marker.
        if t.range(of: #"^([-*+]\s+|\d+[.)]\s+)"#, options: .regularExpression) != nil {
            return true
        }
        // Markdown heading.
        if t.range(of: #"^#{1,6}\s+\S"#, options: .regularExpression) != nil { return true }
        // Shell prompt gutter.
        if t.hasPrefix("$ ") || t.hasPrefix("# ") || t.hasPrefix("> ") { return true }
        // Command-shaped: long flag, KEY=val at start, or backslash continuation.
        if t.hasSuffix("\\") { return true }
        if t.range(of: #"(^|\s)--[a-zA-Z]"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^[A-Z_][A-Z0-9_]*="#, options: .regularExpression) != nil { return true }
        return false
    }

    private func displayWidth(_ s: String) -> Int {
        // Trailing whitespace at the wrap boundary doesn't contribute to the
        // visible column. Tabs become 4 (terminals vary, but for the spread
        // check this is precise enough).
        var trimmedTrailing = Substring(s)
        while let last = trimmedTrailing.last, last == " " || last == "\t" {
            trimmedTrailing.removeLast()
        }
        var w = 0
        for ch in trimmedTrailing {
            w += (ch == "\t") ? 4 : 1
        }
        return w
    }
}
