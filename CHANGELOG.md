# Changelog

All notable changes to Klyp will be documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.10] - 2026-05-14

### Added
- **Source-aware soft-wrap collapse.** Klyp now records the bundle ID of the
  app that wrote each clipboard entry. When you copy from a terminal whose
  window is narrow enough to wrap a long message into hard-newlined chunks
  (Ghostty, iTerm, Terminal, Warp, etc.) and then paste into a non-terminal
  target (chat, email, notes), Klyp joins those wrapped lines back into a
  single line — preserving real paragraph breaks. Gated on the existing
  master trim toggle and `Terminal aggressiveness ≠ Off`. Pasting back into
  a terminal keeps the line breaks (you pulled them out for a reason).

### Fixed
- Verified that pinned items survive a restart end-to-end with regression
  tests against a real on-disk history file, not just the in-memory store.



### Build
- The release `.app` is now notarized by Apple and stapled, in addition to
  the existing Developer ID signature. First-launch Gatekeeper prompts
  ("downloaded from the internet") are gone, and a fresh install no longer
  requires a quarantine bypass. No behavior changes vs. 0.1.8.

## [0.1.8] - 2026-05-12

### Added
- **Markdown extraction on paste into terminals.** When the target app is a
  terminal, Klyp now pulls runnable content out of Markdown-shaped text
  before flattening: fenced code blocks (``` … ``` or `~~~ … ~~~`, with or
  without a language tag) have their bodies extracted, and text that's
  uniformly indented (e.g. commands quoted under a chat bullet) is
  dedented. Surrounding prose is dropped. Pastes into non-terminal apps
  keep the original Markdown — the trim is only applied where it helps.
  New toggle in Settings → Trimming ("Extract code from Markdown
  (terminals)"), on by default. The `⌥`-held raw paste still bypasses it.

## [0.1.7] - 2026-05-11

### Fixed
- Smart-trim now actually fires when pasting into terminals. v0.1.6 looked
  up the frontmost app at paste time, but Klyp had already activated itself
  to show the popover — so the lookup returned `com.edihasaj.klyp` and the
  terminal-aggressiveness branch was never taken. Klyp now snapshots the
  previously frontmost app *before* activating, and uses that bundle ID
  when deciding whether to trim.

## [0.1.6] - 2026-05-11

### Added
- **Smart-trim on paste.** Multi-line shell snippets you copy from blogs,
  READMEs, or chat output (with backslash continuations, prompt gutters,
  pipes across lines, box-drawing characters) are flattened into a single
  runnable line at paste time — but only when the focused app is a terminal
  (Terminal, iTerm, Ghostty, Warp, kitty, WezTerm, Hyper, Alacritty).
  Prose, Markdown, bullet lists, YAML/JSON, and Python blocks are left
  alone. The original clipboard entry is never mutated, so the same item
  pastes flat into Ghostty and unchanged into TextEdit.
- New **Trimming** tab in Settings with a master toggle, separate
  aggressiveness pickers (Off / Low / Normal / High) for terminals vs.
  general apps, and switches for blank-line preservation and box-drawing
  stripping. Default: on, Normal in terminals, Off elsewhere.
- Hold `⌥` (Option) while pasting — by click, `↵`, or `⌘1`–`⌘9` — to skip
  the trim and paste the original text. The popover footer now shows the
  `⌥↵ Raw` hint and each row's context menu has a "Paste Original" entry.

## [0.1.5] - 2026-05-09

### Added
- App icon — gradient squircle with a stacked-cards mark and a warm pin
  accent, rendered at every macOS size (16 px through 1024 px). Replaces
  the default Xcode icon in the Applications folder, Dock, and About window.
- Menu-bar icon now matches the brand: a custom stacked-cards mark that
  renders as a template (auto-tints to white in dark menu bars / black in
  light) when idle, and switches to brand pink while the popover is open
  (mirrors the active-state pattern used by ChirpGo).

## [0.1.4] - 2026-05-09

### Fixed
- `⌘1`–`⌘9` quick-paste and `⌘P` pin shortcuts (advertised in the footer)
  are now actually wired up.
- Clicking a row used to take 1–3 seconds to register because a single-tap
  selection gesture and a double-tap paste gesture were fighting over the
  same hit area; clicking a row now pastes immediately, matching how other
  clipboard managers behave.
- File previewability detection no longer hits the filesystem on every
  redraw — results are cached per path so scrolling a long history stays
  smooth.

## [0.1.3] - 2026-05-09

### Added
- File-based clipboard items (screenshots, photos, videos, PDFs copied from
  Finder, Photos, etc.) now show real QuickLook thumbnails in the history
  list instead of a generic doc icon. Thumbnails are generated asynchronously
  with a memory + on-disk cache under `~/Library/Application Support/Klyp/Thumbnails/`,
  and fall back gracefully to the doc icon when QuickLook can't render.

## [0.1.2] - 2026-05-09

### Changed
- Release builds are now notarized and stapled by Apple, so first launch via
  Homebrew or a direct download no longer trips Gatekeeper's "developer cannot
  be verified" dialog and the manual `xattr` quarantine workaround is gone.

## [0.1.1] - 2026-05-07

### Fixed
- Pin/unpin from the row context menu now updates immediately (was a missed
  `@Observable` change notification when mutating array elements through a
  subscript).
- Image previews in the history list are now 56×56 with `.fit` so the whole
  image is visible at a glance, and image rows have a subtle border.

## [0.1.0] - 2026-05-07

### Added
- Initial release: menu-bar clipboard history for text, rich text, images,
  file references, and URLs.
- Configurable history size (5–200, default 10) with pinned-item retention.
- Search-as-you-type popover with `⌘1–9` quick paste.
- Global hotkey `⌃Space` (Carbon-registered) to toggle the popover.
- Paste-back synthesizes `⌘V` to the previously-frontmost app.
- Settings window with launch-at-login toggle (`SMAppService`).
- About window showing build version.
- Persisted history under `~/Library/Application Support/Klyp/`.
