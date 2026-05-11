import SwiftUI
import AppKit

struct HistoryView: View {
    @Environment(ClipboardStore.self) private var store
    @Environment(AppCoordinator.self) private var coordinator
    @State private var query: String = ""
    @State private var selection: Int = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 360, height: 480)
        .background(.regularMaterial)
        .onAppear { searchFocused = true; selection = 0 }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search clipboard…", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { pasteCurrent() }
                .onKeyPress(.upArrow) { selection = max(0, selection - 1); return .handled }
                .onKeyPress(.downArrow) { selection = min(filtered.count - 1, selection + 1); return .handled }
                .onKeyPress(.escape) { coordinator.close(); return .handled }
                .onKeyPress(phases: .down) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    let chars = press.characters
                    if chars == "p" || chars == "P" {
                        guard selection < filtered.count else { return .handled }
                        store.togglePin(id: filtered[selection].id)
                        return .handled
                    }
                    if let n = Int(chars), (1...9).contains(n) {
                        let idx = n - 1
                        guard idx < filtered.count else { return .handled }
                        pasteItem(filtered[idx])
                        return .handled
                    }
                    return .ignored
                }
            Spacer()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text(store.items.isEmpty ? "Copy something to get started." : "No matches.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            HistoryRowView(
                                item: item,
                                index: index,
                                isSelected: index == selection,
                                onPaste: { pasteItem(item) },
                                onPasteRaw: { pasteItem(item, forceRaw: true) },
                                onPin: { store.togglePin(id: item.id) },
                                onDelete: { store.delete(id: item.id) }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .onChange(of: selection) { _, new in
                    guard new < filtered.count else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(filtered[new].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerHint("↵", "Paste")
            footerHint("⌘1–9", "Quick")
            footerHint("⌘P", "Pin")
            footerHint("⌥↵", "Raw")
            Spacer()
            Menu {
                Button("Settings…") { coordinator.openSettings() }
                Button("About Klyp") { coordinator.openAbout() }
                Divider()
                Button("Clear Unpinned") { store.clearAll() }
                Divider()
                Button("Quit Klyp") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thickMaterial)
    }

    private func footerHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var filtered: [ClipboardItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sorted = store.items.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
        guard !q.isEmpty else { return sorted }
        return sorted.filter { item in
            item.text.lowercased().contains(q)
                || (item.filePaths?.contains { $0.lowercased().contains(q) } ?? false)
        }
    }

    private func pasteCurrent() {
        guard selection < filtered.count else { return }
        pasteItem(filtered[selection])
    }

    private func pasteItem(_ item: ClipboardItem, forceRaw: Bool = false) {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        coordinator.paste(item, forceRaw: forceRaw || optionHeld)
    }
}
