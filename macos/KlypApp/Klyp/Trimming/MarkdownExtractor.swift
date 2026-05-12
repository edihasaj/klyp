import Foundation

/// Pulls runnable content out of Markdown-formatted text (e.g. an LLM reply).
/// Two passes:
///
/// 1. Fenced code blocks (```…``` or ~~~…~~~): if any exist, return the
///    concatenated bodies — surrounding prose is discarded.
/// 2. Otherwise, if every non-blank line shares a leading indent ≥ 2 spaces,
///    strip that common indent. This catches commands quoted under a chat
///    bullet or block-quote.
///
/// Returns nil when neither rule applies — caller keeps the original text.
/// Pure value type; safe to unit-test.
struct MarkdownExtractor: Sendable {
    static func extract(_ input: String) -> String? {
        if let fenced = extractFencedBlocks(input) {
            return fenced
        }
        if let dedented = dedentCommonIndent(input) {
            return dedented
        }
        return nil
    }

    // MARK: - Fenced blocks

    /// Concatenates the bodies of every fenced block in `input`, joined by a
    /// single newline. Returns nil if no closed fence is found.
    static func extractFencedBlocks(_ input: String) -> String? {
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [String] = []
        var current: [String]? = nil
        var fenceChar: Character? = nil
        var fenceIndent: String = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let char = fenceChar {
                if isFenceLine(trimmed, char: char) {
                    if let body = current { blocks.append(body.joined(separator: "\n")) }
                    current = nil
                    fenceChar = nil
                    fenceIndent = ""
                } else {
                    // CommonMark: body lines may share the opening fence's
                    // indent. Strip it so a 2-space-indented fence around a
                    // command doesn't paste with the gutter intact.
                    let stripped = line.hasPrefix(fenceIndent)
                        ? String(line.dropFirst(fenceIndent.count))
                        : line
                    current?.append(stripped)
                }
            } else if let char = openingFenceChar(in: trimmed) {
                fenceChar = char
                fenceIndent = String(line.prefix { $0 == " " || $0 == "\t" })
                current = []
            }
        }

        // Unclosed fence: treat the rest as a block anyway. Common for partial
        // copies from a chat UI where the closing fence didn't get selected.
        if let body = current, !body.isEmpty {
            blocks.append(body.joined(separator: "\n"))
        }

        guard !blocks.isEmpty else { return nil }
        return blocks.joined(separator: "\n")
    }

    /// Returns the fence character ("`" or "~") if `line` starts with ≥ 3 of
    /// the same fence character. A language tag after the run is fine.
    private static func openingFenceChar(in line: String) -> Character? {
        for char: Character in ["`", "~"] {
            let run = line.prefix(while: { $0 == char })
            if run.count >= 3 { return char }
        }
        return nil
    }

    /// True if `line` is purely a fence row of the given character (≥ 3 of
    /// them, with no language tag — i.e. a closing fence).
    private static func isFenceLine(_ line: String, char: Character) -> Bool {
        let run = line.prefix(while: { $0 == char })
        guard run.count >= 3 else { return false }
        return run.count == line.count
    }

    // MARK: - Common-indent dedent

    /// If every non-blank line shares a leading indent ≥ 2 spaces (or any tab),
    /// strip that indent and return the result. Otherwise nil.
    ///
    /// This catches the common case where commands quoted in a chat reply land
    /// on the clipboard with a 2- or 4-space gutter from the surrounding list
    /// or block-quote.
    static func dedentCommonIndent(_ input: String) -> String? {
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let nonBlank = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonBlank.count >= 2 else { return nil }

        let indents = nonBlank.map { leadingWhitespace($0) }
        guard let minIndent = indents.min(), !minIndent.isEmpty else { return nil }
        // Require ≥ 2 spaces worth of indent so we don't strip a normal
        // single-space prefix.
        let effective = minIndent.replacingOccurrences(of: "\t", with: "    ")
        guard effective.count >= 2 else { return nil }
        // All non-blank lines must literally begin with `minIndent`.
        guard nonBlank.allSatisfy({ $0.hasPrefix(minIndent) }) else { return nil }

        let out = lines.map { line -> String in
            line.hasPrefix(minIndent) ? String(line.dropFirst(minIndent.count)) : line
        }
        let result = out.joined(separator: "\n")
        return result == input ? nil : result
    }

    private static func leadingWhitespace(_ s: String) -> String {
        String(s.prefix { $0 == " " || $0 == "\t" })
    }
}
