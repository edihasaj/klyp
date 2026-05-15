import Foundation

/// Strips line-leading gutter glyphs emitted by TUI agents (Claude Code,
/// Codex CLI, etc.). When you copy a long reply out of a narrow terminal
/// window, the clipboard ends up with things like:
///
///     ⏺ Here's a draft reply:
///       ▎ first paragraph that has been
///       ▎ wrapped across two lines
///       ▎
///       ▎ second paragraph
///
/// The `⏺` is a status bullet and `▎` is a blockquote bar — both purely
/// decorative for the terminal renderer, and both meaningless (or actively
/// harmful) when pasted into a chat box.
///
/// Conservative by design — only fires when the gutter glyphs appear on at
/// least two lines (so a lone `⏺` in arbitrary text is left alone), and the
/// glyph set is restricted to characters that don't realistically show up in
/// command output. Box-drawing chars (`│ ┃`) are deliberately excluded — they
/// appear in `tree`, `git log --graph`, and framed table output.
struct TUIGutterStripper: Sendable {
    /// Glyphs treated as TUI gutter markers. Each may optionally be followed
    /// by a single space before the line's real content.
    static let glyphs: Set<Character> = ["\u{23FA}", "\u{258E}", "\u{23BF}"] // ⏺ ▎ ⎿

    /// Returns the input with gutter glyphs removed, or nil if the input
    /// doesn't contain enough gutter signal to act on.
    func stripIfGuttered(_ input: String) -> String? {
        guard !input.isEmpty else { return nil }
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var matchCount = 0
        for line in lines where matches(line) != nil {
            matchCount += 1
            if matchCount >= 2 { break }
        }
        guard matchCount >= 2 else { return nil }

        let out = lines.map { line -> String in
            guard let m = matches(line) else { return line }
            // m.bodyStart is the UTF-16 index where the line's real content
            // begins (after the leading whitespace + glyph + optional space).
            return String(line[m.bodyStart...])
        }
        let joined = out.joined(separator: "\n")
        return joined == input ? nil : joined
    }

    // MARK: - Per-line match

    /// A line matches if it looks like `<optional spaces><glyph>(<space>|$)`.
    /// The returned index points past the gutter, at the start of the body.
    private struct Match {
        let bodyStart: String.Index
    }

    private func matches(_ line: String) -> Match? {
        var idx = line.startIndex
        // Skip leading horizontal whitespace.
        while idx < line.endIndex, line[idx] == " " || line[idx] == "\t" {
            idx = line.index(after: idx)
        }
        guard idx < line.endIndex, Self.glyphs.contains(line[idx]) else { return nil }
        // Past the glyph.
        let afterGlyph = line.index(after: idx)
        // If anything follows, it must be a single space (or end of line) —
        // otherwise the glyph is glued to text and likely meaningful content,
        // not a gutter.
        if afterGlyph == line.endIndex {
            return Match(bodyStart: afterGlyph)
        }
        if line[afterGlyph] == " " {
            return Match(bodyStart: line.index(after: afterGlyph))
        }
        return nil
    }
}
