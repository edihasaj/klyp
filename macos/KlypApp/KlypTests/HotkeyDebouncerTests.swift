import XCTest
@testable import Klyp

final class HotkeyDebouncerTests: XCTestCase {
    func testSuppressesDelayedDeliveryFromOtherSource() {
        var debouncer = HotkeyDebouncer()

        XCTAssertTrue(debouncer.shouldFire(id: 1, source: .eventTap, at: 100))
        XCTAssertFalse(debouncer.shouldFire(id: 1, source: .carbon, at: 100.3))
        XCTAssertTrue(debouncer.shouldFire(id: 1, source: .eventTap, at: 100.4))
        XCTAssertFalse(debouncer.shouldFire(id: 1, source: .carbon, at: 100.8))
    }

    func testAllowsCarbonWhenEventTapStopsDelivering() {
        var debouncer = HotkeyDebouncer()

        XCTAssertTrue(debouncer.shouldFire(id: 1, source: .eventTap, at: 100))
        XCTAssertFalse(debouncer.shouldFire(id: 1, source: .carbon, at: 100.9))
        XCTAssertTrue(debouncer.shouldFire(id: 1, source: .carbon, at: 101.1))
    }

    func testSuppressesRapidRepeatWithoutBlockingAnotherShortcut() {
        var debouncer = HotkeyDebouncer()

        XCTAssertTrue(debouncer.shouldFire(id: 1, source: .carbon, at: 100))
        XCTAssertFalse(debouncer.shouldFire(id: 1, source: .carbon, at: 100.1))
        XCTAssertTrue(debouncer.shouldFire(id: 1, source: .carbon, at: 100.2))
        XCTAssertTrue(debouncer.shouldFire(id: 2, source: .carbon, at: 100.2))
    }
}
