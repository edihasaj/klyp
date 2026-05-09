<p align="center">
  <img src="docs/icon.png" alt="Klyp" width="160" height="160">
</p>

<h1 align="center">Klyp</h1>

A lightweight, modern clipboard history manager for macOS. Lives in your menu
bar, remembers everything you copy — text, images, files, URLs — and pastes it
back with a keystroke.

Built in SwiftUI for macOS 14+. Free and open-source. A successor in spirit to
CopyClip and CopyClip 2 — but one that doesn't fall over.

## Features

- 📋 Tracks text, rich text, images, file references (videos, PDFs, anything),
  and URLs.
- 🔍 Searchable popover that follows your light/dark system theme.
- ⌨️ Global hotkey (default `⌃Space`) — leaves `⇧⌘V` free for editor paste-and-match.
- 🔢 Configurable history size (default 10, up to 200).
- 📌 Pin items so they survive eviction.
- 🧊 Lives in the menu bar only — no Dock icon, minimal CPU.
- 🎨 Native macOS look across light/dark and accent colors.

## Install

### Homebrew (recommended, once published)

```bash
brew install --cask edihasaj/tap/klyp
```

### From source

```bash
git clone https://github.com/edihasaj/klyp.git
cd klyp/macos/KlypApp
xcodegen
xcodebuild -scheme Klyp -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual
open build/Build/Products/Release/Klyp.app
```

## Permissions

On first paste-back, macOS will ask for **Accessibility** permission so Klyp
can synthesize `⌘V` into the focused app. Grant it under
*System Settings → Privacy & Security → Accessibility*.

Klyp does not phone home. History stays on your machine in
`~/Library/Application Support/Klyp/`.

## Default Shortcuts

| Action                       | Shortcut |
| ---------------------------- | -------- |
| Toggle Klyp popover          | `⌃Space` |
| Paste item N (in popover)    | `⌘1–9`   |
| Search                       | type any letter |
| Clear history                | `⌘⌫`     |
| Pin/unpin selected           | `⌘P`     |

## Roadmap

- [ ] Excluded apps (skip 1Password, etc.)
- [ ] Sync across Macs (CloudKit, opt-in)
- [ ] Smart paste (strip formatting on `⌥` modifier)
- [ ] Notarized + signed release builds

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Issues and PRs welcome.

## License

[MIT](LICENSE).
