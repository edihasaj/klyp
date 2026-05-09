# Changelog

All notable changes to Klyp will be documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
