import XCTest
@testable import Klyp

final class TUIGutterStripperTests: XCTestCase {
    private let stripper = TUIGutterStripper()

    // MARK: - Positive cases

    func testStripsClaudeCodeBlockquoteAndStatusBullet() {
        let input = """
        ⏺ Here's a draft reply:

          ▎ Thanks for reaching out. Before setting up a private disclosure channel,
          ▎ I'd like to validate the report.
          ▎
          ▎ If the concern is purely defense-in-depth, that's fair to discuss in
          ▎ the open as a hardening issue rather than a security advisory.
        """
        let expected = """
        Here's a draft reply:

        Thanks for reaching out. Before setting up a private disclosure channel,
        I'd like to validate the report.

        If the concern is purely defense-in-depth, that's fair to discuss in
        the open as a hardening issue rather than a security advisory.
        """
        XCTAssertEqual(stripper.stripIfGuttered(input), expected)
    }

    func testStripsGutterOnlyLinesToBlank() {
        let input = """
          ▎ paragraph one
          ▎
          ▎ paragraph two
        """
        let expected = """
        paragraph one

        paragraph two
        """
        XCTAssertEqual(stripper.stripIfGuttered(input), expected)
    }

    func testStripsToolResultMarker() {
        let input = """
        ⏺ Running command
          ⎿ output line one
          ⎿ output line two
        """
        let expected = """
        Running command
        output line one
        output line two
        """
        XCTAssertEqual(stripper.stripIfGuttered(input), expected)
    }

    // MARK: - Negative cases (must not corrupt)

    func testIgnoresGitLogGraph() {
        // `│` is intentionally NOT in the glyph set — git log --graph relies on
        // these characters and stripping them would destroy the graph layout.
        let input = """
        * 7c1bf2b chore: bump cask to 0.1.10
        │ * abc1234 feat: new thing
        │/
        * 549cf06 feat: collapse terminal soft-wrap on paste
        """
        XCTAssertNil(stripper.stripIfGuttered(input))
    }

    func testIgnoresTreeOutput() {
        let input = """
        src
        ├── foo
        │   └── bar.swift
        └── baz.swift
        """
        XCTAssertNil(stripper.stripIfGuttered(input))
    }

    func testIgnoresMarkdownDotBulletInProse() {
        // ● is a real bullet here, not a gutter. Stripper leaves it alone
        // because it's not in the glyph set.
        let input = """
        Key points:
        ● first
        ● second
        ● third
        """
        XCTAssertNil(stripper.stripIfGuttered(input))
    }

    func testIgnoresPsqlBoxTable() {
        let input = """
         id │ name
        ────┼─────────
          1 │ alice
          2 │ bob
        """
        XCTAssertNil(stripper.stripIfGuttered(input))
    }

    func testRequiresAtLeastTwoGutteredLines() {
        // A lone ⏺ in arbitrary text should not be stripped — could be the
        // user's own use of the glyph.
        let input = """
        ⏺ Recording note for later
        nothing else looks like a gutter here
        """
        XCTAssertNil(stripper.stripIfGuttered(input))
    }

    func testIgnoresGlyphGluedToText() {
        // Glyph immediately followed by non-space → not a gutter, treat as
        // content (some symbol the user actually wrote).
        let input = """
        ⏺recording: started
        ⏺recording: stopped
        """
        XCTAssertNil(stripper.stripIfGuttered(input))
    }

    func testIgnoresEmpty() {
        XCTAssertNil(stripper.stripIfGuttered(""))
    }

    func testIgnoresPlainText() {
        XCTAssertNil(stripper.stripIfGuttered("just a regular sentence with no glyphs"))
    }
}
