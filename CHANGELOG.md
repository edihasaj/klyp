# Changelog

All notable changes to Klyp will be documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial release: menu-bar clipboard history for text, rich text, images,
  file references, and URLs.
- Configurable history size (5–200, default 10) with pinned-item retention.
- Search-as-you-type popover with `⌘1–9` quick paste.
- Global hotkey `⇧⌘V` (Carbon-registered) to toggle the popover.
- Paste-back synthesizes `⌘V` to the previously-frontmost app.
- Settings window with launch-at-login toggle (`SMAppService`).
- About window showing build version.
- Persisted history under `~/Library/Application Support/Klyp/`.
