import Foundation
import Observation

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    var maxItems: Int

    private let persistQueue = DispatchQueue(label: "klyp.persist", qos: .utility)
    private let fileURL = AppPaths.historyFile

    init(maxItems: Int = 10) {
        self.maxItems = maxItems
        load()
    }

    /// Insert a new item. Returns true if accepted (false if dedup matched the most-recent entry).
    @discardableResult
    func insert(_ item: ClipboardItem) -> Bool {
        // If we already have an item with the same hash, just move it to top
        // and refresh its createdAt so it doesn't immediately get evicted.
        if let idx = items.firstIndex(where: { $0.hash == item.hash }) {
            var existing = items.remove(at: idx)
            existing = ClipboardItem(
                id: existing.id,
                kind: existing.kind,
                createdAt: Date(),
                text: existing.text,
                rtfData: existing.rtfData,
                imageFilename: existing.imageFilename,
                filePaths: existing.filePaths,
                hash: existing.hash,
                pinned: existing.pinned
            )
            items.insert(existing, at: 0)
            persist()
            return false
        }
        items.insert(item, at: 0)
        evict()
        persist()
        return true
    }

    func delete(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: idx)
        if let filename = removed.imageFilename {
            try? FileManager.default.removeItem(at: AppPaths.imageCacheDir.appendingPathComponent(filename))
        }
        persist()
    }

    func togglePin(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        persist()
    }

    func clearAll() {
        for item in items where !item.pinned {
            if let filename = item.imageFilename {
                try? FileManager.default.removeItem(at: AppPaths.imageCacheDir.appendingPathComponent(filename))
            }
        }
        items.removeAll(where: { !$0.pinned })
        persist()
    }

    func setMaxItems(_ n: Int) {
        maxItems = max(1, min(n, 500))
        evict()
        persist()
    }

    private func evict() {
        // Pinned items are always kept; only unpinned can be dropped.
        let pinnedCount = items.filter(\.pinned).count
        let cap = max(maxItems, pinnedCount)
        guard items.count > cap else { return }

        var keep: [ClipboardItem] = []
        var unpinnedSeen = 0
        let unpinnedAllowed = max(cap - pinnedCount, 0)
        for item in items {
            if item.pinned {
                keep.append(item)
            } else if unpinnedSeen < unpinnedAllowed {
                keep.append(item)
                unpinnedSeen += 1
            } else {
                if let filename = item.imageFilename {
                    try? FileManager.default.removeItem(at: AppPaths.imageCacheDir.appendingPathComponent(filename))
                }
            }
        }
        items = keep
    }

    private func persist() {
        let snapshot = items
        let url = fileURL
        persistQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("[Klyp] persist failed: \(error)")
            }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            items = decoded
        }
    }
}
