import AppKit
import XCTest
@testable import Klyp

@MainActor
final class CursorPanelTests: XCTestCase {
    private let screen = NSRect(x: 100, y: 50, width: 1000, height: 700)
    private let panel = NSSize(width: 360, height: 480)

    func testOpensBelowAndRightOfPointerWhenThereIsRoom() {
        let origin = CursorPanel.origin(
            near: NSPoint(x: 400, y: 700), size: panel, visibleFrame: screen
        )
        XCTAssertEqual(origin, NSPoint(x: 412, y: 208))
    }

    func testFlipsAtBottomRightCorner() {
        let origin = CursorPanel.origin(
            near: NSPoint(x: 1050, y: 80), size: panel, visibleFrame: screen
        )
        XCTAssertEqual(origin, NSPoint(x: 678, y: 92))
    }

    func testStaysInsideVisibleFrameOnSmallDisplay() {
        let smallScreen = NSRect(x: -500, y: 100, width: 300, height: 400)
        let origin = CursorPanel.origin(
            near: NSPoint(x: -210, y: 110), size: panel, visibleFrame: smallScreen
        )
        XCTAssertEqual(origin, smallScreen.origin)
    }
}
