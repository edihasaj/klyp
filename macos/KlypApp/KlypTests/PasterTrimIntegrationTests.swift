import XCTest
@testable import Klyp

/// End-to-end check of `Paster.applyTrim` — exercises the
/// MarkdownExtractor → CommandTrimmer pipeline against a terminal target.
/// Each test resets `UserDefaults` keys to known values so it's independent
/// of the developer's local Klyp settings.
@MainActor
final class PasterTrimIntegrationTests: XCTestCase {
    private let ghostty = "com.mitchellh.ghostty"
    private let textEdit = "com.apple.TextEdit"

    override func setUp() {
        super.setUp()
        let d = UserDefaults.standard
        d.set(true, forKey: TrimSettings.Keys.enabled)
        d.set(Aggressiveness.normal.rawValue, forKey: TrimSettings.Keys.terminalLevel)
        d.set(Aggressiveness.off.rawValue, forKey: TrimSettings.Keys.generalLevel)
        d.set(true, forKey: TrimSettings.Keys.preserveBlankLines)
        d.set(true, forKey: TrimSettings.Keys.removeBoxDrawing)
        d.set(true, forKey: TrimSettings.Keys.extractMarkdown)
    }

    override func tearDown() {
        let d = UserDefaults.standard
        for key in [
            TrimSettings.Keys.enabled,
            TrimSettings.Keys.terminalLevel,
            TrimSettings.Keys.generalLevel,
            TrimSettings.Keys.preserveBlankLines,
            TrimSettings.Keys.removeBoxDrawing,
            TrimSettings.Keys.extractMarkdown,
        ] {
            d.removeObject(forKey: key)
        }
        super.tearDown()
    }

    private func makeItem(_ text: String, sourceBundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            text: text,
            rtfData: nil,
            imageFilename: nil,
            filePaths: nil,
            hash: text,
            pinned: false,
            sourceBundleID: sourceBundleID
        )
    }

    // MARK: - Markdown extraction (terminal target)

    func testFencedCommandIntoTerminal() {
        let input = """
        Run this to install:

        ```bash
        brew install foo
        ```

        Then you're good.
        """
        let out = Paster.applyTrim(makeItem(input), targetBundleID: ghostty)
        XCTAssertEqual(out.text, "brew install foo")
    }

    func testIndentedHeredocIntoTerminal() {
        // Reproduces the user's reported case: a heredoc copied from an LLM
        // reply with a 2-space chat-bubble gutter on every line. Should
        // dedent — and CommandTrimmer should not flatten a heredoc.
        let input = """
          sudo bash <<'EOF'
          echo "=== ss listeners ==="
          ss -lntp | grep ':443'
          EOF
        """
        let expected = """
        sudo bash <<'EOF'
        echo "=== ss listeners ==="
        ss -lntp | grep ':443'
        EOF
        """
        let out = Paster.applyTrim(makeItem(input), targetBundleID: ghostty)
        XCTAssertEqual(out.text, expected)
    }

    func testFencedThenFlattenedBackslashContinuation() {
        // Markdown extraction strips the fence; CommandTrimmer flattens the
        // backslash-continued command inside.
        let input = """
        ```
        kubectl get pods \\
            -n kube-system \\
            -o json
        ```
        """
        let out = Paster.applyTrim(makeItem(input), targetBundleID: ghostty)
        XCTAssertEqual(out.text, "kubectl get pods -n kube-system -o json")
    }

    // MARK: - Non-terminal target leaves Markdown alone

    func testFencedCommandIntoTextEditUnchanged() {
        let input = """
        ```bash
        brew install foo
        ```
        """
        let out = Paster.applyTrim(makeItem(input), targetBundleID: textEdit)
        XCTAssertEqual(out.text, input,
                       "Pasting into a non-terminal app must preserve original Markdown.")
    }

    func testIndentedCommandIntoTextEditUnchanged() {
        let input = """
          sudo bash <<'EOF'
          echo hi
          EOF
        """
        let out = Paster.applyTrim(makeItem(input), targetBundleID: textEdit)
        XCTAssertEqual(out.text, input)
    }

    // MARK: - Master toggle gating

    func testExtractMarkdownOffDisablesExtraction() {
        UserDefaults.standard.set(false, forKey: TrimSettings.Keys.extractMarkdown)
        let input = """
        ```
        brew install foo
        ```
        """
        let out = Paster.applyTrim(makeItem(input), targetBundleID: ghostty)
        // Trimmer alone won't touch a fenced block (`looksLikeFencedCode`
        // gate), so the result should be the original text.
        XCTAssertEqual(out.text, input)
    }

    func testTrimMasterToggleOffStillAllowsExtraction() {
        // Even with the trimmer disabled, markdown extraction alone should
        // still help in a terminal — it's gated by its own toggle.
        UserDefaults.standard.set(false, forKey: TrimSettings.Keys.enabled)
        let input = """
        ```
        echo hi
        ```
        """
        let out = Paster.applyTrim(makeItem(input), targetBundleID: ghostty)
        XCTAssertEqual(out.text, "echo hi")
    }

    // MARK: - Plain prose passes through

    func testPlainProseUnchanged() {
        let input = "This is just a sentence with nothing interesting."
        let out = Paster.applyTrim(makeItem(input), targetBundleID: ghostty)
        XCTAssertEqual(out.text, input)
    }

    // MARK: - Soft-wrap collapse for terminal-source pastes

    func testGhosttySourcePastedIntoTextEditCollapsesSoftWrap() {
        // Reproduces the reported bug: a chat message copied from a narrow
        // ghostty window has hard newlines at the wrap column. Pasting into
        // TextEdit (or any non-terminal app) should collapse them to spaces.
        let input = """
        hello there this is a fairly long message that
        ghostty wrapped at a narrow window and inserted
        hard newlines in the middle of my sentence
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(
            out.text,
            "hello there this is a fairly long message that ghostty wrapped at a narrow window and inserted hard newlines in the middle of my sentence"
        )
    }

    func testGhosttySourcePastedBackIntoGhosttyKeepsBreaks() {
        // Pasting back into a terminal: user pulled the multi-line content
        // out for a reason. Don't re-flatten on re-entry.
        let input = """
        hello there this is a fairly long message that
        ghostty wrapped at a narrow window and inserted
        hard newlines in the middle of my sentence
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: ghostty)
        XCTAssertEqual(out.text, input)
    }

    func testSoftWrapCollapseRespectsMasterToggle() {
        UserDefaults.standard.set(false, forKey: TrimSettings.Keys.enabled)
        let input = """
        hello there this is a fairly long message that
        ghostty wrapped at a narrow window and inserted
        hard newlines in the middle of my sentence
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(out.text, input, "Master trim toggle off must disable soft-wrap collapse.")
    }

    func testSoftWrapCollapseRespectsTerminalLevelOff() {
        UserDefaults.standard.set(Aggressiveness.off.rawValue, forKey: TrimSettings.Keys.terminalLevel)
        let input = """
        hello there this is a fairly long message that
        ghostty wrapped at a narrow window and inserted
        hard newlines in the middle of my sentence
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(out.text, input, "terminalLevel = .off must disable soft-wrap collapse.")
    }

    func testClaudeCodeReplyStripsGutterAndCollapsesWraps() {
        // Real-world case: copying a Claude Code reply out of a narrow
        // Ghostty window. Status bullet + blockquote gutter on every line,
        // plus soft-wrap newlines mid-sentence. Should come out as clean
        // paragraphs ready to paste into a chat box.
        let input = """
        ⏺ Here's a draft reply:

          ▎ Thanks for reaching out. Before setting up a private disclosure
          ▎ channel, I'd like to validate the report.
          ▎
          ▎ If the concern is purely defense in depth, that's fair to discuss
          ▎ in the open as a hardening issue rather than a security advisory.
        """
        let expected = """
        Here's a draft reply:

        Thanks for reaching out. Before setting up a private disclosure channel, I'd like to validate the report.

        If the concern is purely defense in depth, that's fair to discuss in the open as a hardening issue rather than a security advisory.
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(out.text, expected)
    }

    func testGitLogGraphFromTerminalNotCorrupted() {
        // git log --graph uses │ ╱ ╲ glyphs that are NOT in the TUI gutter
        // set. The stripper must leave them alone so the graph survives.
        let input = """
        * 7c1bf2b chore: bump cask
        │ * abc1234 feat: new thing
        │/
        * 549cf06 feat: collapse terminal soft-wrap on paste into chat
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(out.text, input,
                       "git log --graph output must survive the trim pipeline unchanged.")
    }

    func testTreeOutputFromTerminalNotCorrupted() {
        let input = """
        src
        ├── foo
        │   └── bar.swift
        └── baz.swift
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(out.text, input)
    }

    func testGutterStripRespectsTerminalLevelOff() {
        UserDefaults.standard.set(Aggressiveness.off.rawValue, forKey: TrimSettings.Keys.terminalLevel)
        let input = """
          ▎ first line of a wrapped quote
          ▎ second line continues the quote
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(out.text, input,
                       "terminalLevel = .off must disable gutter stripping.")
    }

    func testGutterStripSkippedWhenPastingBackIntoTerminal() {
        // User pulled a multi-line quote out of a TUI for a reason. The
        // gutter glyphs must survive on re-entry into the terminal —
        // disable markdown extraction so only the new terminal-source
        // pipeline (gutter strip + soft-wrap collapse) is under test.
        UserDefaults.standard.set(false, forKey: TrimSettings.Keys.extractMarkdown)
        let input = """
          ▎ first line of a wrapped quote
          ▎ second line continues the quote
        """
        let item = makeItem(input, sourceBundleID: ghostty)
        let out = Paster.applyTrim(item, targetBundleID: ghostty)
        XCTAssertEqual(out.text, input)
    }

    func testNonTerminalSourceLeavesWrappedTextAlone() {
        // Same wrapped shape but copied from a non-terminal — could be
        // intentional formatting (poetry, formatted prose). Don't touch.
        let input = """
        hello there this is a fairly long message that
        someone formatted with manual breaks deliberately
        for some stylistic reason in their note app
        """
        let item = makeItem(input, sourceBundleID: textEdit)
        let out = Paster.applyTrim(item, targetBundleID: textEdit)
        XCTAssertEqual(out.text, input)
    }
}
