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

    private func makeItem(_ text: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            text: text,
            rtfData: nil,
            imageFilename: nil,
            filePaths: nil,
            hash: text,
            pinned: false
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
}
