import XCTest
@testable import Klyp

final class SoftWrapCollapserTests: XCTestCase {
    private let collapser = SoftWrapCollapser()

    // MARK: - Positive cases (should collapse)

    func testCollapsesNarrowGhosttyWrap() {
        // A typical chat sentence wrapped at ~50 cols inside a narrow
        // terminal. All non-final lines are similar widths.
        let input = """
        hello there this is a fairly long message that
        ghostty wrapped at a narrow window and inserted
        hard newlines in the middle of my sentence
        """
        let expected = "hello there this is a fairly long message that ghostty wrapped at a narrow window and inserted hard newlines in the middle of my sentence"
        XCTAssertEqual(collapser.collapseIfSoftWrapped(input), expected)
    }

    func testPreservesParagraphBreaks() {
        let input = """
        first paragraph that wraps across two lines for
        layout reasons inside the terminal window today

        second paragraph also wrapped across a couple of
        lines but logically separate from the first one
        """
        let expected = """
        first paragraph that wraps across two lines for layout reasons inside the terminal window today

        second paragraph also wrapped across a couple of lines but logically separate from the first one
        """
        XCTAssertEqual(collapser.collapseIfSoftWrapped(input), expected)
    }

    // MARK: - Negative cases (should leave untouched)

    func testIgnoresBulletList() {
        let input = """
        - first item that happens to be quite long here
        - second item also long enough to look wrapped
        - third item rounding out the list nicely too
        """
        XCTAssertNil(collapser.collapseIfSoftWrapped(input))
    }

    func testIgnoresFencedCode() {
        let input = """
        ```
        kubectl get pods --all-namespaces -o wide today
        kubectl describe pod foo --namespace bar please
        ```
        """
        XCTAssertNil(collapser.collapseIfSoftWrapped(input))
    }

    func testIgnoresShellPromptLines() {
        let input = """
        $ git log --oneline --all --decorate today please
        $ git status --porcelain --untracked-files=normal
        """
        XCTAssertNil(collapser.collapseIfSoftWrapped(input))
    }

    func testIgnoresBackslashContinuation() {
        let input = """
        kubectl get pods --all-namespaces -o wide \\
            --selector app=foo --field-selector x=y
        """
        XCTAssertNil(collapser.collapseIfSoftWrapped(input))
    }

    func testIgnoresShortLines() {
        // Short, varied lines look like intentional structure (poetry, short
        // replies, etc.) — don't touch.
        let input = """
        yes
        ok
        sure
        """
        XCTAssertNil(collapser.collapseIfSoftWrapped(input))
    }

    func testIgnoresLargeWidthSpread() {
        // One short line in the middle indicates a real break, not a wrap.
        let input = """
        this is a long line that fills the terminal cols
        short
        and another long line that fills the same width
        """
        XCTAssertNil(collapser.collapseIfSoftWrapped(input))
    }

    func testIgnoresSingleLine() {
        XCTAssertNil(collapser.collapseIfSoftWrapped("just one line of text here, no wrap"))
    }

    func testIgnoresEmpty() {
        XCTAssertNil(collapser.collapseIfSoftWrapped(""))
    }

    func testIgnoresMarkdownHeading() {
        let input = """
        # Release notes for the long-awaited new version
        Some prose body that would otherwise look wrapped
        across multiple lines just like terminal output
        """
        XCTAssertNil(collapser.collapseIfSoftWrapped(input))
    }
}
