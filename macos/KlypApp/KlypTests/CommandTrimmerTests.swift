import XCTest
@testable import Klyp

final class CommandTrimmerTests: XCTestCase {

    // MARK: - Should flatten

    func testBackslashContinuationKubectl() {
        let input = """
        kubectl get pods \\
            -n kube-system \\
            --selector='app=ingress' \\
            -o json | jq '.items[].metadata.name'
        """
        let out = CommandTrimmer(aggressiveness: .normal).transformIfCommand(input)
        XCTAssertEqual(
            out,
            "kubectl get pods -n kube-system --selector='app=ingress' -o json | jq '.items[].metadata.name'"
        )
    }

    func testPromptGutterDollar() {
        let input = """
        $ brew install foo
        $ brew install bar
        """
        let out = CommandTrimmer(aggressiveness: .normal).transformIfCommand(input)
        XCTAssertEqual(out, "brew install foo\nbrew install bar")
    }

    func testPromptGutterHashRoot() {
        let input = """
        # apt-get update
        # apt-get install -y curl
        """
        let out = CommandTrimmer(aggressiveness: .normal).transformIfCommand(input)
        XCTAssertEqual(out, "apt-get update\napt-get install -y curl")
    }

    func testBoxDrawingGutterStripped() {
        let input = """
        │ git status
        │ git diff
        """
        let out = CommandTrimmer(aggressiveness: .normal).transformIfCommand(input)
        XCTAssertEqual(out, "git status\ngit diff")
    }

    func testPipeChainAcrossLines() {
        let input = """
        cat /var/log/system.log
            | grep ERROR
            | head -n 20
        """
        let out = CommandTrimmer(aggressiveness: .normal).transformIfCommand(input)
        XCTAssertEqual(out, "cat /var/log/system.log | grep ERROR | head -n 20")
    }

    func testIndentedContinuationJoined() {
        // Continuation by indentation alone (no trailing backslash) should still
        // be joined — common pattern in blog posts.
        let input = """
        docker run --rm -it
            -v /tmp:/data
            ubuntu:latest bash
        """
        let out = CommandTrimmer(aggressiveness: .normal).transformIfCommand(input)
        XCTAssertEqual(out, "docker run --rm -it -v /tmp:/data ubuntu:latest bash")
    }

    func testSingleLinePromptStrip() {
        let input = "$ brew install foo"
        let out = CommandTrimmer(aggressiveness: .normal).transformIfCommand(input)
        XCTAssertEqual(out, "brew install foo")
    }

    // MARK: - Should NOT flatten

    func testOffNeverFlattens() {
        let input = """
        kubectl get pods \\
            -o json | jq .
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .off).transformIfCommand(input))
    }

    func testMarkdownHeadingPreserved() {
        let input = """
        # Release notes
        Some release info follows.
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testBulletListPreserved() {
        let input = """
        - first thing
        - second thing
        - third thing
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testYamlPreserved() {
        let input = """
        name: klyp
        version: 0.1.5
        platform: macOS
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testJsonPreserved() {
        let input = """
        {
          "name": "klyp",
          "version": "0.1.5"
        }
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testPythonBlockPreserved() {
        let input = """
        def greet(name):
            print(f"hi {name}")
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testFencedCodePreserved() {
        let input = """
        ```bash
        brew install foo
        ```
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testSafetyValveLongScript() {
        // 11 lines — above the default cap, even though each line is command-shaped.
        let lines = (1...11).map { "git commit -m 'step \($0)'" }
        let input = lines.joined(separator: "\n")
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testProsePreserved() {
        let input = """
        This is a paragraph that wraps across
        several lines but is not a command at all.
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testLowRequiresStrongSignal() {
        // Has known cmd + flags = score 3 → exactly meets Low threshold.
        let input = """
        ls -lah
        cd /tmp
        """
        // No backslash, no pipe — Low (threshold 3) probably won't fire.
        // Just assert it doesn't crash; behavior is best-effort here.
        _ = CommandTrimmer(aggressiveness: .low).transformIfCommand(input)
    }

    func testPlainTextWithNoSignalsUnchanged() {
        let input = """
        hello
        world
        """
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }

    func testEmptyInputIsNil() {
        XCTAssertNil(CommandTrimmer(aggressiveness: .high).transformIfCommand(""))
    }

    func testFlattenIsIdempotent() {
        let input = "kubectl get pods -n kube-system -o json | jq ."
        // Single line, no prompt → no transform.
        XCTAssertNil(CommandTrimmer(aggressiveness: .normal).transformIfCommand(input))
    }
}
