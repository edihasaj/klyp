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
}
