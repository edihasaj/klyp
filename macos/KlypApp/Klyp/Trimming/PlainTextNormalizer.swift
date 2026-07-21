import Foundation

/// Deterministic "clean this up" pass for the **Paste as Plain Text** mode.
///
/// The smart-trim path (`CommandTrimmer` → `TUIGutterStripper` →
/// `SoftWrapCollapser`) is heuristic on purpose: it must never mangle text the
/// user pasted by reflex. The cost is that it bails out often — a stray flag,
/// an uneven wrap column, a `--` in a sentence — which is why copying a reply
/// out of a narrow Claude Code / Codex window sometimes keeps its gutter bars,
/// its indentation, or the hard newlines the terminal inserted at the wrap
/// column.
///
/// This normalizer is the opposite contract: the user asked for it explicitly
/// (⇧↵ / "Paste as Plain Text"), so it always acts. No scoring, no whole-input
/// bailouts.
///
///     ⏺ Here's the summary:
///       ▎ this paragraph was wrapped by the
///       ▎ terminal at 60 columns
///       ▎
///       ▎ second paragraph
///
/// becomes
///
///     Here's the summary:
///
///     this paragraph was wrapped by the terminal at 60 columns
///
///     second paragraph
///
/// Structure that carries meaning is still respected line-by-line (no
/// heuristics, just a lookahead): blank lines keep paragraphs apart, list
/// items / headings / table rows stay on their own lines, and fenced code
/// blocks are passed through verbatim.
struct PlainTextNormalizer: Sendable {
    /// Line-leading decoration to remove. TUI status/elbow glyphs plus the
    /// vertical bars agents use as quote gutters. Box-drawing *corners*
    /// (`└ ├`) are deliberately absent — they carry structure in `tree` and
    /// `git log --graph` output.
    static let gutterGlyphs: Set<Character> = [
        "\u{23FA}", // ⏺ status bullet
        "\u{23BF}", // ⎿ tool-result elbow
        "\u{2502}", "\u{2503}", // │ ┃
        "\u{2506}", "\u{2507}", "\u{2508}", "\u{2509}", "\u{250A}", "\u{250B}", // dashed verticals
        "\u{254E}", "\u{254F}", // ╎ ╏
        "\u{2551}", // ║
        "\u{258F}", "\u{258E}", "\u{258D}", "\u{258C}", // ▏ ▎ ▍ ▌
        "\u{258B}", "\u{258A}", "\u{2589}", "\u{2588}", "\u{2590}", // ▋ ▊ ▉ █ ▐
    ]

    static func normalize(_ input: String) -> String {
        guard !input.isEmpty else { return input }

        let rawLines = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        // Pass 1 — per-line cleanup. Fenced blocks keep their body verbatim
        // (minus the gutter) because indentation is content inside code.
        var cleaned: [String] = []
        var fenceDepth = 0
        for raw in rawLines {
            // `tree` / `git log --graph` output uses the same vertical bars as
            // a TUI gutter, but there they are load-bearing. Pass those lines
            // through untouched rather than degrading them into prose.
            if isTreeLine(raw) {
                cleaned.append(trimTrailing(raw))
                continue
            }
            let degutterred = stripGutter(raw)
            let trimmed = degutterred.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fenceDepth = fenceDepth == 0 ? 1 : 0
                cleaned.append(trimmed)
                continue
            }
            if fenceDepth > 0 {
                cleaned.append(trimTrailing(degutterred))
            } else {
                cleaned.append(collapseSpaces(trimmed))
            }
        }

        // Pass 2 — join soft-wrapped lines, keep real structure apart.
        var out: [String] = []
        var pending: String?
        var inFence = false

        func flush() {
            if let p = pending, !p.isEmpty { out.append(p) }
            pending = nil
        }

        for line in cleaned {
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                flush()
                out.append(line)
                inFence.toggle()
                continue
            }
            if inFence {
                flush()
                out.append(line)
                continue
            }
            if line.isEmpty {
                flush()
                // Collapse runs of blank lines to a single separator.
                if out.last?.isEmpty == false { out.append("") }
                continue
            }
            if let current = pending, joinable(previous: current, next: line) {
                pending = current + " " + line
            } else {
                flush()
                pending = line
            }
        }
        flush()

        while out.first?.isEmpty == true { out.removeFirst() }
        while out.last?.isEmpty == true { out.removeLast() }
        return out.joined(separator: "\n")
    }

    // MARK: - Line cleanup

    /// Removes any run of leading whitespace + gutter glyphs, e.g. `"  ▎ │ hi"`
    /// → `"hi"`. Repeats because nested quoting stacks the bars.
    private static func stripGutter(_ line: String) -> String {
        var idx = line.startIndex
        var lastBodyStart = idx
        while idx < line.endIndex {
            // Skip leading horizontal whitespace.
            var cursor = idx
            while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
                cursor = line.index(after: cursor)
            }
            guard cursor < line.endIndex, gutterGlyphs.contains(line[cursor]) else { break }
            cursor = line.index(after: cursor)
            // A single space after the glyph is part of the gutter, not the body.
            if cursor < line.endIndex, line[cursor] == " " {
                cursor = line.index(after: cursor)
            }
            idx = cursor
            lastBodyStart = cursor
        }
        return String(line[lastBodyStart...])
    }

    /// A branch glyph anywhere in the line means the vertical bars around it
    /// are drawing a tree, not quoting text.
    private static func isTreeLine(_ line: String) -> Bool {
        line.contains("\u{2514}") || line.contains("\u{251C}") // └ ├
    }

    private static func trimTrailing(_ s: String) -> String {
        var out = Substring(s)
        while let last = out.last, last == " " || last == "\t" { out.removeLast() }
        return String(out)
    }

    private static func collapseSpaces(_ s: String) -> String {
        guard s.contains("\t") || s.range(of: "  ") != nil else { return s }
        return s
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
    }

    // MARK: - Join rules

    /// Two adjacent non-blank lines are treated as one wrapped paragraph unless
    /// either side is structural.
    private static func joinable(previous: String, next: String) -> Bool {
        if startsBlock(next) { return false }
        if standsAlone(previous) { return false }
        return true
    }

    /// Lines that must start on their own line.
    private static func startsBlock(_ line: String) -> Bool {
        if isTreeLine(line) { return true }
        if line.range(of: #"^([-*+•]\s+|\d+[.)]\s+)"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^#{1,6}\s+\S"#, options: .regularExpression) != nil { return true }
        if line.hasPrefix("|") { return true }          // table row
        if line.hasPrefix("> ") { return true }         // block quote
        if line.hasPrefix("$ ") { return true }         // shell prompt
        return false
    }

    /// Lines that must end on their own line — anything the next line would
    /// visually belong *under*, not *after*.
    private static func standsAlone(_ line: String) -> Bool {
        if isTreeLine(line) { return true }
        if line.range(of: #"^#{1,6}\s+\S"#, options: .regularExpression) != nil { return true }
        if line.hasPrefix("|") { return true }
        if line.hasPrefix("$ ") { return true }
        return false
    }
}
