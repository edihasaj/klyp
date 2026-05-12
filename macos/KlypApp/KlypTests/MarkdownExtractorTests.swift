import XCTest
@testable import Klyp

final class MarkdownExtractorTests: XCTestCase {

    // MARK: - Fenced code blocks

    func testSingleFencedBlockBash() {
        let input = """
        Run this:
        ```bash
        brew install foo
        brew install bar
        ```
        Then enjoy.
        """
        XCTAssertEqual(
            MarkdownExtractor.extract(input),
            "brew install foo\nbrew install bar"
        )
    }

    func testFencedBlockNoLanguageTag() {
        let input = """
        ```
        echo hi
        ```
        """
        XCTAssertEqual(MarkdownExtractor.extract(input), "echo hi")
    }

    func testTildeFence() {
        let input = """
        ~~~sh
        ls -la
        ~~~
        """
        XCTAssertEqual(MarkdownExtractor.extract(input), "ls -la")
    }

    func testMultipleFencedBlocksJoined() {
        let input = """
        First do:
        ```
        cd /tmp
        ```
        Then:
        ```
        ./run.sh
        ```
        """
        XCTAssertEqual(MarkdownExtractor.extract(input), "cd /tmp\n./run.sh")
    }

    func testUnclosedFenceStillExtracts() {
        let input = """
        ```
        ssh user@host
        echo done
        """
        XCTAssertEqual(MarkdownExtractor.extract(input), "ssh user@host\necho done")
    }

    func testInlineCodeIsNotExtracted() {
        let input = "Use `git status` to see changes."
        XCTAssertNil(MarkdownExtractor.extract(input))
    }

    func testPlainProseReturnsNil() {
        let input = "This is a short paragraph with no code at all."
        XCTAssertNil(MarkdownExtractor.extract(input))
    }

    // MARK: - Dedent

    func testDedentTwoSpaceGutter() {
        let input = """
          sudo bash <<'EOF'
          echo hi
          EOF
        """
        XCTAssertEqual(
            MarkdownExtractor.extract(input),
            "sudo bash <<'EOF'\necho hi\nEOF"
        )
    }

    func testDedentFourSpaceGutter() {
        let input = """
            git status
            git diff
        """
        XCTAssertEqual(MarkdownExtractor.extract(input), "git status\ngit diff")
    }

    func testNoDedentWhenIndentInconsistent() {
        let input = """
          line one
        line two
        """
        XCTAssertNil(MarkdownExtractor.extract(input))
    }

    func testNoDedentForSingleSpace() {
        let input = """
         line one
         line two
        """
        XCTAssertNil(MarkdownExtractor.extract(input))
    }

    func testSingleLineReturnsNil() {
        // Need at least 2 non-blank lines to even consider dedent.
        let input = "  echo hi"
        XCTAssertNil(MarkdownExtractor.extract(input))
    }

    // MARK: - Fenced wins over dedent

    func testFencedBlockPreferredOverIndent() {
        let input = """
          Surrounding prose at 2-space indent.
          ```
          echo only-me
          ```
          More prose.
        """
        XCTAssertEqual(MarkdownExtractor.extract(input), "echo only-me")
    }
}
