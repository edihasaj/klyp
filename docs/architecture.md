# Klyp Architecture

Single-target SwiftUI macOS app, lifecycle owned by an `NSApplicationDelegate`.

```
KlypApp.swift              — @main entry; installs AppDelegate; Settings scene
└─ AppDelegate             — bootstraps coordinator on launch
   └─ AppCoordinator       — wires watcher + menu bar + hotkey + paste
      ├─ ClipboardStore    — @Observable history; persists to JSON
      ├─ PasteboardWatcher — polls NSPasteboard.changeCount @ 0.3 s
      ├─ MenuBarController — NSStatusItem + NSPopover (host: HistoryView)
      ├─ HotkeyManager     — Carbon RegisterEventHotKey for ⇧⌘V
      └─ Paster            — restores item to pasteboard, synthesizes ⌘V
```

## Clipboard kinds

- `text` — plain UTF-8.
- `richText` — RTF data + plain fallback.
- `image` — cached as PNG under `~/Library/Application Support/Klyp/Images/`,
  filename = SHA-256 of pixel data.
- `files` — file:// URLs (videos, PDFs, anything Finder copies).
- `url` — when the pasteboard advertises `.URL` (typed-link copy).

## Persistence

- `~/Library/Application Support/Klyp/history.json` — full history (items only,
  no binary blobs).
- `~/Library/Application Support/Klyp/Images/` — image PNG cache.

The store writes asynchronously on a utility queue after every mutation.

## Dedupe

`ClipboardItem.hash` is a SHA-256 of a kind-prefixed payload. On insert, an
existing matching hash is moved to the top instead of duplicated.

## Eviction

Only unpinned items can be evicted. With cap `N` and `P` pinned, up to
`max(N, P)` items are retained, dropping the oldest unpinned first.

## Pasteboard race handling

After `clearContents()` and before the next `writeObjects`, the pasteboard
briefly reports no types. The watcher retries up to 3 polls before advancing
its `lastChangeCount`, so legitimate writes aren't lost across the gap. Cross-
process file URL writes that use `NSPasteboardWriting` callbacks (NSURL) are
only readable while the writer is alive — that's not a Klyp limitation, it's
how `writeObjects([NSURL])` works in macOS. Real apps (Finder, browsers) keep
running.

## Permissions

- **Accessibility** is required only when Klyp synthesizes `⌘V` to paste. We
  prompt the system on first paste; until granted, items still get placed on
  the pasteboard so the user can `⌘V` themselves.
- **No other permissions**: not sandboxed, no network use.
