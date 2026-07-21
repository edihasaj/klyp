# Releasing Klyp

## 1. Bump version

In `macos/KlypApp/project.yml`:

```yaml
settings:
  base:
    MARKETING_VERSION: "0.2.0"
    CURRENT_PROJECT_VERSION: "2"
```

Then `cd macos/KlypApp && xcodegen` to regenerate the project.

## 2. Build a release zip

```bash
./scripts/build-app.sh
```

This produces:

- `dist/Klyp.app` — built and ad-hoc signed
- `dist/Klyp.app.zip` — the asset to attach to a GitHub release
- The script also prints the SHA-256 of the zip — you'll need it for the cask.

Un-notarized artifacts are renamed `Klyp.app.DEV.zip` and must never be
published — that is what produced the "Klyp is damaged" Gatekeeper failures
fixed in 0.1.9. To build a publishable zip:

```bash
KLYP_SIGN_IDENTITY="2BD41E421590DEAEB6AA3726E2457E6C0CC532A9" \
KLYP_NOTARY_PROFILE=klyp \
./scripts/build-app.sh
```

Two gotchas:

- **Pass the certificate's SHA-1, not its name.** The login keychain holds
  three certs all named `Developer ID Application: Applifyer, LLC
  (T8J48M4QVY)`, so `codesign` fails with `ambiguous (matches …)`. List them
  with `security find-identity -v -p codesigning`.
- **The notary profile is per-machine keychain state**, so a fresh Mac has
  none. Recreate it from the 1Password item `apple id app password -
  NOTARIZATION` (username + password fields, team `T8J48M4QVY`):

  ```bash
  xcrun notarytool store-credentials klyp \
    --apple-id "$(op item get 'apple id app password - NOTARIZATION' --fields label=username --reveal)" \
    --team-id T8J48M4QVY \
    --password "$(op item get 'apple id app password - NOTARIZATION' --fields label=password --reveal)"
  ```

## 3. Tag and publish

```bash
VERSION=0.2.0
git tag -a v$VERSION -m "Klyp v$VERSION"
git push origin v$VERSION
gh release create v$VERSION dist/Klyp.app.zip \
  --title "Klyp v$VERSION" \
  --generate-notes
```

## 4. Update Homebrew cask

In `~/Projects/homebrew-tap/Casks/klyp.rb` (copy from `packaging/klyp.rb`, then
run `brew style` — the tap has previously carried fixes that the repo copy
lacked, and blindly copying over them regresses the cask):

```ruby
version "0.2.0"
sha256 "<paste the sha-256 from build-app.sh>"
```

```bash
cd ~/Projects/homebrew-tap
git checkout -b cask/klyp-$VERSION
# edit Casks/klyp.rb
brew style ./Casks/klyp.rb
brew audit --new-cask --token-conflicts ./Casks/klyp.rb
git commit -am "klyp $VERSION"
git push -u origin HEAD
gh pr create --title "klyp $VERSION" --body "Cask bump."
```

The first time we publish, also create the cask in the tap with:

```bash
cp ~/Projects/klyp/packaging/klyp.rb ~/Projects/homebrew-tap/Casks/klyp.rb
```

After the cask PR merges, users can install with:

```bash
brew install --cask edihasaj/tap/klyp
```
