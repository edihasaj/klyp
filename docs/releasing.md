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

> **Notarization**: The build is currently ad-hoc signed. For distribution
> outside Homebrew, sign with a Developer ID certificate and notarize. See
> `notarytool submit ... --wait`.

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

In `~/Projects/homebrew-tap/Casks/klyp.rb` (copy from `packaging/klyp.rb`):

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
