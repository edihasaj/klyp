import Foundation

/// Decides whether a multi-line clipboard string is a shell command that
/// should be flattened into a single line, and (if so) produces the flat
/// form. Models Trimmy's scoring approach.
///
/// Pure value type — no AppKit, no pasteboard. Safe to unit-test.
struct CommandTrimmer: Sendable {
    let aggressiveness: Aggressiveness
    let preserveBlankLines: Bool
    let removeBoxDrawing: Bool

    init(
        aggressiveness: Aggressiveness,
        preserveBlankLines: Bool = true,
        removeBoxDrawing: Bool = true
    ) {
        self.aggressiveness = aggressiveness
        self.preserveBlankLines = preserveBlankLines
        self.removeBoxDrawing = removeBoxDrawing
    }

    /// Returns the flattened command if the input looks command-shaped and
    /// passes the aggressiveness threshold; otherwise nil.
    func transformIfCommand(_ input: String) -> String? {
        guard aggressiveness != .off else { return nil }
        guard !input.isEmpty else { return nil }

        // Strip box-drawing chars first — they don't count as content for any
        // heuristic and they'd otherwise cause a flatten to leave junk behind.
        let cleaned = removeBoxDrawing ? stripBoxDrawing(input) : input
        let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Single-line input: only worth touching if there's a prompt gutter to strip.
        if lines.count == 1 {
            let stripped = stripPromptGutter(lines[0])
            return stripped == input ? nil : stripped
        }

        let minLines = 2
        let maxLines = aggressiveness.maxLines
        guard (minLines...maxLines).contains(lines.count) else { return nil }

        guard !looksLikeFencedCode(lines) else { return nil }
        guard !looksLikeMarkdown(lines) else { return nil }
        guard !looksLikeList(lines) else { return nil }
        guard !looksLikeStructuredData(lines) else { return nil }

        let score = scoreSignals(lines)
        guard score >= aggressiveness.scoreThreshold else { return nil }

        let flattened = flatten(lines)
        return flattened == input ? nil : flattened
    }

    // MARK: - Signal scoring

    private func scoreSignals(_ lines: [String]) -> Int {
        var score = 0

        // 1. Backslash continuations (very strong).
        let backslashLines = lines.dropLast().filter { $0.trimmingCharacters(in: .whitespaces).hasSuffix("\\") }
        if !backslashLines.isEmpty { score += 2 }

        // 2. Pipes / logical operators inline.
        let opPattern = lines.contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.contains(" | ") || t.contains(" || ") || t.contains(" && ")
                || t.hasSuffix("|") || t.hasSuffix("&&") || t.hasSuffix("||")
        }
        if opPattern { score += 2 }

        // 3. Prompt gutters ($ / # followed by space, not Markdown headings).
        let prompts = lines.filter { hasPromptGutter($0) }
        if !prompts.isEmpty { score += 2 }

        // 4. Known command prefix on the first non-blank, non-prompt line.
        if let head = firstCommandHead(lines), Self.knownCommands.contains(head) {
            score += 2
        }

        // 5. Command punctuation: flags, KEY=val, paths.
        let punct = lines.contains { hasCommandPunctuation($0) }
        if punct { score += 1 }

        // 6. Indented continuation — second+ lines indented further than first.
        if hasIndentedContinuation(lines) { score += 1 }

        return score
    }

    // MARK: - Heuristic helpers

    private func hasPromptGutter(_ line: String) -> Bool {
        let t = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = t.first else { return false }
        guard first == "$" || first == "#" else { return false }
        let rest = t.dropFirst()
        // Must be "$ " or "# " — Markdown heading ("# Title") is excluded by
        // looksLikeMarkdown, but at the signal level we still want a space.
        return rest.first == " "
    }

    private func stripPromptGutter(_ line: String) -> String {
        guard hasPromptGutter(line) else { return line }
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        let rest = line.dropFirst(leading.count)
        // drop "$ " / "# "
        return String(leading) + String(rest.dropFirst(2))
    }

    private func hasCommandPunctuation(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return false }
        // Long flag: --foo
        if t.range(of: #"(^|\s)--[a-zA-Z]"#, options: .regularExpression) != nil { return true }
        // Short flag: -f, -abc (but not a lone "-")
        if t.range(of: #"(^|\s)-[a-zA-Z]"#, options: .regularExpression) != nil { return true }
        // KEY=value at the start of a token.
        if t.range(of: #"(^|\s)[A-Z_][A-Z0-9_]*="#, options: .regularExpression) != nil { return true }
        // Path-ish tokens.
        if t.contains("/") && !t.hasPrefix("//") { return true }
        return false
    }

    private func hasIndentedContinuation(_ lines: [String]) -> Bool {
        guard lines.count >= 2 else { return false }
        let firstIndent = leadingSpaces(lines[0])
        for line in lines.dropFirst() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if leadingSpaces(line) > firstIndent { return true }
        }
        return false
    }

    private func leadingSpaces(_ s: String) -> Int {
        var n = 0
        for ch in s {
            if ch == " " { n += 1 }
            else if ch == "\t" { n += 4 }
            else { break }
        }
        return n
    }

    private func firstCommandHead(_ lines: [String]) -> String? {
        for line in lines {
            let raw = stripPromptGutter(line).trimmingCharacters(in: .whitespaces)
            if raw.isEmpty { continue }
            // Skip env-var-only lines ("FOO=bar baz" → use baz). Simple split.
            let parts = raw.split(separator: " ", omittingEmptySubsequences: true)
            for p in parts {
                if p.contains("=") { continue }
                return String(p).lowercased()
            }
            return nil
        }
        return nil
    }

    // MARK: - Negative gates

    private func looksLikeFencedCode(_ lines: [String]) -> Bool {
        lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
    }

    /// Heading like "# Release notes" (capital, more than just `# word`),
    /// or multiple lines that look like prose paragraphs.
    private func looksLikeMarkdown(_ lines: [String]) -> Bool {
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            // Markdown ATX headings: "# ", "## ", … followed by some content.
            // Match the prefix only so the tail keeps every leading char.
            guard let m = t.range(of: #"^#{1,6}\s+"#, options: .regularExpression) else { continue }
            let tail = String(t[m.upperBound...])
            guard !tail.isEmpty else { continue }
            // If the heading text contains a flag, path, or pipe, it's almost
            // certainly a quoted shell command on a prompt line — defer to
            // the scorer. Otherwise it's a real heading.
            if hasCommandPunctuation(tail) || tail.contains("|") {
                continue
            }
            // Also defer if the first token is a known command (e.g. "# git status").
            let firstToken = tail.split(separator: " ", maxSplits: 1).first.map(String.init) ?? tail
            if Self.knownCommands.contains(firstToken.lowercased()) {
                continue
            }
            return true
        }
        return false
    }

    private func looksLikeList(_ lines: [String]) -> Bool {
        // 2+ lines starting with -, *, +, or "1. " / "1) " bullets.
        var bulletCount = 0
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.range(of: #"^([-*+]\s+|\d+[.)]\s+)"#, options: .regularExpression) != nil {
                bulletCount += 1
            }
        }
        return bulletCount >= 2
    }

    /// YAML, JSON, Python, etc. — content where newlines carry meaning.
    private func looksLikeStructuredData(_ lines: [String]) -> Bool {
        let nonBlank = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonBlank.isEmpty else { return false }

        // YAML: a `key: value` pair with no command punctuation on 2+ lines.
        let yamlLike = nonBlank.filter { line in
            guard line.range(of: #"^\s*[A-Za-z_][\w-]*:\s"#, options: .regularExpression) != nil
                else { return false }
            return !hasCommandPunctuation(line)
        }
        if yamlLike.count >= 2 { return true }

        // JSON-ish: starts with { or [ and ends with } or ].
        let firstChar = nonBlank.first?.trimmingCharacters(in: .whitespaces).first
        let lastChar = nonBlank.last?.trimmingCharacters(in: .whitespaces).last
        if (firstChar == "{" || firstChar == "[") && (lastChar == "}" || lastChar == "]") {
            return true
        }

        // Python def/class/if blocks: ends with `:` and next line is indented.
        for (i, line) in nonBlank.enumerated() where i + 1 < nonBlank.count {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasSuffix(":")
                && (t.hasPrefix("def ") || t.hasPrefix("class ")
                    || t.hasPrefix("if ") || t.hasPrefix("for ")
                    || t.hasPrefix("while ") || t.hasPrefix("with ")
                    || t.hasPrefix("else") || t.hasPrefix("elif "))
            {
                return true
            }
        }

        return false
    }

    // MARK: - Flatten

    private func flatten(_ lines: [String]) -> String {
        var out: [String] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]

            // Preserve intentionally blank lines verbatim.
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if preserveBlankLines { out.append("") }
                i += 1
                continue
            }

            var accumulator = stripPromptGutter(line)
                .trimmingCharacters(in: .whitespaces)

            // Join continuations: trailing `\`, or indented next-line.
            while i + 1 < lines.count {
                let next = lines[i + 1]
                let nextTrim = next.trimmingCharacters(in: .whitespaces)
                if nextTrim.isEmpty { break }

                let endsWithBackslash = accumulator.hasSuffix("\\")
                let nextIndented = leadingSpaces(next) > leadingSpaces(line)

                if endsWithBackslash {
                    accumulator.removeLast()
                    accumulator = accumulator.trimmingCharacters(in: .whitespaces)
                    accumulator += " " + stripPromptGutter(next).trimmingCharacters(in: .whitespaces)
                    i += 1
                    continue
                }
                if nextIndented {
                    accumulator += " " + stripPromptGutter(next).trimmingCharacters(in: .whitespaces)
                    i += 1
                    continue
                }
                break
            }

            // Collapse internal runs of whitespace to single spaces (but keep
            // single newlines between distinct command lines we couldn't join).
            accumulator = collapseSpaces(accumulator)
            out.append(accumulator)
            i += 1
        }

        // Drop trailing blanks introduced by preservation.
        while out.last?.isEmpty == true { out.removeLast() }
        return out.joined(separator: "\n")
    }

    private func collapseSpaces(_ s: String) -> String {
        guard s.range(of: "  ") != nil || s.contains("\t") else { return s }
        return s
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
    }

    private func stripBoxDrawing(_ s: String) -> String {
        // U+2500..U+257F covers the Box Drawing block. Replace with spaces so
        // surrounding tokens stay separated; trim later.
        var out = ""
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            if (0x2500...0x257F).contains(scalar.value) {
                out.append(" ")
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    // MARK: - Known commands

    /// Hardcoded list — kept short. Anything not on this list still trips the
    /// other signals (flags, pipes, prompt). This just adds confidence when
    /// we see a familiar tool name.
    private static let knownCommands: Set<String> = [
        "sudo", "ssh", "scp", "rsync", "curl", "wget", "ping", "nc", "dig",
        "git", "gh", "hub",
        "brew", "apt", "apt-get", "yum", "dnf", "pacman", "port", "snap",
        "npm", "yarn", "pnpm", "bun", "deno", "node", "npx",
        "pip", "pip3", "pipx", "uv", "uvx", "poetry", "python", "python3",
        "cargo", "rustup", "rustc",
        "go", "gofmt",
        "swift", "xcodebuild", "xcrun", "fastlane", "pod",
        "docker", "podman", "compose", "docker-compose",
        "kubectl", "helm", "k9s", "minikube", "kind",
        "terraform", "tofu", "pulumi", "ansible",
        "aws", "gcloud", "az", "doctl",
        "make", "cmake", "ninja", "bazel",
        "bash", "sh", "zsh", "fish", "env", "exec", "source",
        "ls", "cd", "cp", "mv", "rm", "mkdir", "rmdir", "touch", "find",
        "grep", "rg", "ag", "ack", "sed", "awk", "jq", "yq", "fzf",
        "cat", "tail", "head", "less", "more", "wc", "tr", "cut", "sort",
        "echo", "printf", "tee", "xargs",
        "open", "code", "subl", "nvim", "vim", "nano", "emacs",
        "claude",
    ]
}
