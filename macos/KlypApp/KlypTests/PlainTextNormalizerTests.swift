import XCTest
@testable import Klyp

/// `PlainTextNormalizer` backs the ⇧↵ "Paste as Plain Text" mode. Unlike the
/// smart-trim path it has no bailouts, so these tests pin the exact contract:
/// gutters and indentation always go, terminal wraps always rejoin, and real
/// structure (paragraphs, lists, fenced code) always survives.
final class PlainTextNormalizerTests: XCTestCase {
    private func normalize(_ s: String) -> String { PlainTextNormalizer.normalize(s) }

    // MARK: - Gutters

    func testStripsTUIGutterGlyphs() {
        let input = """
        ⏺ Here's the summary:
          ▎ first line
          ▎ second line
        """
        XCTAssertEqual(normalize(input), "Here's the summary: first line second line")
    }

    func testStripsSingleGutterOccurrence() {
        // The heuristic stripper needs 2+ matching lines; plain mode does not.
        XCTAssertEqual(normalize("▎ only one bar here"), "only one bar here")
    }

    func testStripsStackedVerticalBars() {
        XCTAssertEqual(normalize("  │ ▎ nested quote"), "nested quote")
    }

    func testLeavesBoxDrawingCornersAlone() {
        let input = """
        └── src
        ├── main.swift
        """
        XCTAssertEqual(normalize(input), input)
    }

    // MARK: - Whitespace

    func testRemovesLeadingIndentAndTabs() {
        XCTAssertEqual(normalize("\t    indented text"), "indented text")
    }

    func testCollapsesInteriorWhitespaceRuns() {
        XCTAssertEqual(normalize("word     spaced\tout"), "word spaced out")
    }

    func testTrimsTrailingWhitespace() {
        XCTAssertEqual(normalize("trailing   "), "trailing")
    }

    // MARK: - Soft-wrap rejoining

    func testJoinsWrappedLinesRegardlessOfWidthSpread() {
        // SoftWrapCollapser refuses this (widths differ by more than its
        // tolerance); plain mode joins anyway because the user asked.
        let input = """
        this line is fairly long and wrapped
        short
        and another chunk of the same paragraph
        """
        XCTAssertEqual(
            normalize(input),
            "this line is fairly long and wrapped short and another chunk of the same paragraph"
        )
    }

    func testJoinsEvenWithCommandPunctuationPresent() {
        // A `--flag` in prose makes the heuristic collapser bail out entirely.
        let input = """
        pass the --verbose flag when you
        want more output from the tool
        """
        XCTAssertEqual(normalize(input), "pass the --verbose flag when you want more output from the tool")
    }

    func testKeepsParagraphsSeparated() {
        let input = """
        ▎ this paragraph was wrapped by the
        ▎ terminal at sixty columns
        ▎
        ▎ second paragraph
        """
        XCTAssertEqual(
            normalize(input),
            "this paragraph was wrapped by the terminal at sixty columns\n\nsecond paragraph"
        )
    }

    func testCollapsesRunsOfBlankLines() {
        XCTAssertEqual(normalize("one\n\n\n\ntwo"), "one\n\ntwo")
    }

    func testTrimsLeadingAndTrailingBlankLines() {
        XCTAssertEqual(normalize("\n\n  hello  \n\n"), "hello")
    }

    func testNormalizesCarriageReturns() {
        XCTAssertEqual(normalize("alpha\r\nbeta\r\n\r\ngamma"), "alpha beta\n\ngamma")
    }

    // MARK: - Structure preservation

    func testKeepsListItemsOnSeparateLines() {
        let input = """
        ⏺ Steps:
          ▎ - install the tool
          ▎ - run the setup
          ▎ - profit
        """
        XCTAssertEqual(normalize(input), "Steps:\n- install the tool\n- run the setup\n- profit")
    }

    func testJoinsWrappedContinuationIntoItsBullet() {
        let input = """
        - this bullet was wrapped by the
        terminal mid-sentence
        - second bullet
        """
        XCTAssertEqual(normalize(input), "- this bullet was wrapped by the terminal mid-sentence\n- second bullet")
    }

    func testKeepsHeadingsOnTheirOwnLine() {
        XCTAssertEqual(normalize("## Results\nthe run passed"), "## Results\nthe run passed")
    }

    func testPreservesFencedCodeVerbatim() {
        let input = """
        ▎ Try this:
        ▎ ```swift
        ▎ func main() {
        ▎     print("hi")
        ▎ }
        ▎ ```
        """
        XCTAssertEqual(
            normalize(input),
            "Try this:\n```swift\nfunc main() {\n    print(\"hi\")\n}\n```"
        )
    }

    func testKeepsTableRowsOnSeparateLines() {
        let input = """
        | a | b |
        | 1 | 2 |
        """
        XCTAssertEqual(normalize(input), input)
    }

    func testKeepsPromptLinesSeparate() {
        XCTAssertEqual(normalize("$ git status\n$ git log"), "$ git status\n$ git log")
    }

    // MARK: - Degenerate input

    func testEmptyInputUnchanged() {
        XCTAssertEqual(normalize(""), "")
    }

    func testCleanSingleLineUnchanged() {
        XCTAssertEqual(normalize("already clean"), "already clean")
    }

    func testIsIdempotent() {
        let input = """
        ⏺ Here's a reply that the terminal
          ▎ wrapped across several lines
          ▎
          ▎ - with a bullet
        """
        let once = normalize(input)
        XCTAssertEqual(normalize(once), once)
    }
}
