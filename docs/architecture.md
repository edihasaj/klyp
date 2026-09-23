# Klyp Architecture

Single-target SwiftUI macOS app, lifecycle owned by an `NSApplicationDelegate`.

```
KlypApp.swift              — @main entry; installs AppDelegate; Settings scene
└─ AppDelegate             — bootstraps coordinator on launch
   └─ AppCoordinator       — wires watcher + menu bar + hotkey + paste
      ├─ ClipboardStore    — @Observable history; persists to JSON
      ├─ PasteboardWatcher — polls NSPasteboard.changeCount @ 0.3 s
      ├─ MenuBarController — NSStatusItem popover + cursor panel (HistoryView)
      ├─ HotkeyManager     — global ⌃Space and ⌃⇧V shortcuts
      └─ Paster            — restores item to pasteboard, synthesizes ⌘V
```

## Clipboard kinds

- `text` — plain UTF-8.
- `richText` — RTF data + plain fallback.
- `image` — cached as PNG under `~/Library/Application Support/Klyp/Images/`,
  filename = SHA-256 of pixel data.
- `files` — file:// URLs (videos, PDFs, anything Finder copies).
- `url` — when the pasteboard advertises `.URL` (typed-link copy).

## Paste modes

`PasteMode` (in `Paster.swift`) selects what happens on the way back to the
pasteboard. Precedence when a modifier is held: ⌥ beats ⇧.

| Mode       | Trigger              | Transform |
| ---------- | -------------------- | --------- |
| `smart`    | `↵` / click          | Heuristic pipeline gated by `TrimSettings`: `MarkdownExtractor` → `CommandTrimmer` → (terminal source only) `TUIGutterStripper` → `SoftWrapCollapser`. Every stage may decline. |
| `plain`    | `⇧↵` / context menu  | `PlainTextNormalizer` — unconditional. Ignores trim settings and both bundle IDs, and drops RTF so the paste lands unstyled. |
| `unstyled` | `⌃↵`, `⌃⇧V` global  | Drops the RTF payload only. Characters, indentation and line breaks are untouched — for code copied out of an editor that ships syntax colors in the rich-text flavor. |
| `original` | `⌥↵` / context menu  | None; the stored bytes. |

`⌃⇧V` pastes the newest item without opening the popover. Because the user is
still holding `⌃⇧` when it fires, `Paster.whenModifiersReleased` polls until no
modifier is physically down (600 ms cap) before synthesizing `⌘V` — otherwise
the target app receives `⌃⇧⌘V`.

## Global hotkeys

`⌃Space` opens the history picker beside the mouse pointer on its current
display. The panel shifts left or above the pointer near screen edges and stays
inside the display's visible area. Clicking the menu bar icon still opens the
popover below the icon. Both pickers share the same history and paste actions.

`HotkeyManager` owns every Carbon binding (`DefaultHotkey.toggle`,
`DefaultHotkey.pasteUnstyled`) behind one installed event handler, dispatching
on `EventHotKeyID.id`.

When Accessibility access is available, it also installs a session event-tap
fallback. This covers the macOS failure mode where Carbon reports a successful
registration but silently stops delivering events. A short per-binding debounce
prevents both paths from firing the same shortcut twice.

Registration is treated as revocable, not one-shot. Another app can claim the
shortcut minutes or hours after login, and a hot-key ref can survive a
sleep/wake cycle as a non-nil pointer that no longer delivers events — both
present identically to the user as "the shortcut does nothing". So:

- failed registrations retry forever on a capped back-off (2/4/8/16/32/60 s)
  rather than giving up after five attempts;
- every binding is force re-registered (unregister → register) on
  `didWake`, `screensDidWake`, `sessionDidBecomeActive` and the distributed
  `com.apple.screenIsUnlocked` notification.

Registration outcomes are logged with the binding label, so `log show
--predicate 'process == "Klyp"' | grep Hotkey` tells you the current state.

`PlainTextNormalizer` is the deliberate counterweight to the heuristic path:
because the user asked for it explicitly, it never bails out. It strips leading
gutter runs (TUI glyphs `⏺ ⎿` and vertical bars `│ ▎ ┃ …`), removes indentation,
collapses interior whitespace runs, and rejoins consecutive lines — which is
what undoes the hard newlines a narrow terminal inserted at its wrap column.

Structure is preserved by lookahead rather than by bailing out on the whole
input: blank lines separate paragraphs, list items / headings / table rows /
`$ ` prompts stay on their own lines, fenced code blocks pass through verbatim,
and lines containing tree branches (`└ ├`) are left untouched so `tree` and
`git log --graph` output survives.

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
