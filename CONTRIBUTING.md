# Contributing to Klyp

Thanks for helping! Klyp aims to stay small, fast, and predictable.

## Local Setup

Requires macOS 14+ and Xcode 16+.

```bash
brew install xcodegen
cd macos/KlypApp
xcodegen
open KlypApp.xcodeproj
```

## Build & Test

```bash
cd macos/KlypApp
xcodebuild -scheme Klyp -configuration Debug \
  -derivedDataPath build test
```

Or run `scripts/build-app.sh` from the repo root for a release build.

## Code Style

- Swift 6 strict concurrency. No `@MainActor`-leaks; mark UI types accordingly.
- Keep files under ~500 LOC; split when they grow.
- Prefer `@Observable` over `ObservableObject`.
- No third-party dependencies unless absolutely needed — Apple frameworks first.

## Pull Requests

- Describe the user-visible change.
- Include screenshots for UI changes.
- Add or update tests when changing storage/dedupe logic.
- Keep README and `docs/` current with behavior changes.

## Release

Tag a version (`vX.Y.Z`), GitHub Actions will build, sign, and attach the
`.app.zip` to the release. The Homebrew cask in `edihasaj/homebrew-tap` is
updated separately — see `docs/releasing.md`.
