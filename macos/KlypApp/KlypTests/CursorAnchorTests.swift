import AppKit
import XCTest
@testable import Klyp

@MainActor
final class CursorAnchorTests: XCTestCase {
    private let screen = NSRect(x: 100, y: 50, width: 1000, height: 700)

    func testPlacesAnchorBesidePointer() {
        let origin = MenuBarController.anchorOrigin(
            near: NSPoint(x: 400, y: 500), visibleFrame: screen
        )
        XCTAssertEqual(origin, NSPoint(x: 412, y: 488))
    }

    func testClampsAnchorAtDisplayEdge() {
        let origin = MenuBarController.anchorOrigin(
            near: NSPoint(x: 1099, y: 51), visibleFrame: screen
        )
        XCTAssertEqual(origin, NSPoint(x: 1099, y: 50))
    }

    func testClampsAnchorOnSecondaryDisplay() {
        let smallScreen = NSRect(x: -500, y: 100, width: 300, height: 400)
        let origin = MenuBarController.anchorOrigin(
            near: NSPoint(x: -210, y: 110), visibleFrame: smallScreen
        )
        XCTAssertEqual(origin, NSPoint(x: -201, y: 100))
    }

    func testMenuBarHoverUsesAppKitTrackingSelectors() {
        let controller = MenuBarController(coordinator: AppCoordinator())
        XCTAssertTrue(controller.responds(to: NSSelectorFromString("mouseEntered:")))
        XCTAssertTrue(controller.responds(to: NSSelectorFromString("mouseExited:")))
    }
}
