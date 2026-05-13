import XCTest
@testable import Klyp

@MainActor
final class ClipboardStoreTests: XCTestCase {
    func makeStore(max: Int = 5) -> ClipboardStore {
        // Use a temp file so tests don't touch real history.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: tmp)
        let store = ClipboardStore(maxItems: max)
        // We can't override the file URL without exposing it, but for unit
        // tests we simply blow away whatever it loaded.
        for it in store.items { store.delete(id: it.id) }
        return store
    }

    func testInsertNewItem() {
        let store = makeStore()
        let item = ClipboardItem.text("hello", hash: "h1")
        let inserted = store.insert(item)
        XCTAssertTrue(inserted)
        XCTAssertEqual(store.items.first?.text, "hello")
    }

    func testDuplicateMovesToTop() {
        let store = makeStore()
        store.insert(ClipboardItem.text("first", hash: "h1"))
        store.insert(ClipboardItem.text("second", hash: "h2"))
        let again = store.insert(ClipboardItem.text("first", hash: "h1"))
        XCTAssertFalse(again)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.text, "first")
    }

    func testEvictionRespectsCap() {
        let store = makeStore(max: 3)
        for i in 0..<5 {
            store.insert(ClipboardItem.text("t\(i)", hash: "h\(i)"))
        }
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(store.items.first?.text, "t4")
    }

    func testPinnedItemsAreNotEvicted() {
        let store = makeStore(max: 2)
        store.insert(ClipboardItem.text("keep", hash: "k"))
        store.togglePin(id: store.items[0].id)
        store.insert(ClipboardItem.text("a", hash: "a"))
        store.insert(ClipboardItem.text("b", hash: "b"))
        store.insert(ClipboardItem.text("c", hash: "c"))
        XCTAssertTrue(store.items.contains { $0.text == "keep" && $0.pinned })
    }

    func testClearLeavesPinned() {
        let store = makeStore()
        store.insert(ClipboardItem.text("pin", hash: "p"))
        store.togglePin(id: store.items[0].id)
        store.insert(ClipboardItem.text("drop", hash: "d"))
        store.clearAll()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.text, "pin")
    }

    // MARK: - Persistence across restart

    func testPinnedItemsPersistAcrossRestart() {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("klyp-pin-persist-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        // First "session": insert two items, pin one, let evictions push past
        // the cap so the pin must survive on its own merits.
        do {
            let store = ClipboardStore(maxItems: 2, fileURL: file)
            store.insert(ClipboardItem.text("keepme", hash: "k"))
            store.togglePin(id: store.items[0].id)
            store.insert(ClipboardItem.text("noise-a", hash: "a"))
            store.insert(ClipboardItem.text("noise-b", hash: "b"))
            store.insert(ClipboardItem.text("noise-c", hash: "c"))
            store.waitForPendingPersist()
        }

        // Second "session": fresh store off the same file. The pinned item
        // must be there with its pin flag intact.
        let reopened = ClipboardStore(maxItems: 2, fileURL: file)
        XCTAssertTrue(
            reopened.items.contains { $0.text == "keepme" && $0.pinned },
            "Pinned item must survive a restart with its pin flag set."
        )
    }

    func testTogglingUnpinPersists() {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("klyp-pin-toggle-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            let store = ClipboardStore(maxItems: 5, fileURL: file)
            store.insert(ClipboardItem.text("x", hash: "x"))
            let id = store.items[0].id
            store.togglePin(id: id)
            store.togglePin(id: id) // unpin again
            store.waitForPendingPersist()
        }

        let reopened = ClipboardStore(maxItems: 5, fileURL: file)
        XCTAssertEqual(reopened.items.first?.pinned, false,
                       "Unpinning must persist — not silently re-pin on reload.")
    }
}
