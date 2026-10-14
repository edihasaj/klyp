---
summary: Mac App Store candidate configuration, signing, and remaining release gates.
read_when:
  - Shipping Klyp to the Mac App Store
  - Changing sandbox entitlements, clipboard access, or release signing
---

# Mac App Store

The store candidate uses `macos/KlypApp/project-app-store.yml`, bundle ID
`com.edihasaj.klyp`, and Applifyer team `T8J48M4QVY`. It builds for both Apple
Silicon and Intel on macOS 14+. The overlay enables App Sandbox and read-only
access to user-selected files. It requests no network entitlement.

This configuration is a release candidate, not a submitted or validated store
release. The existing Developer ID release process remains in
[releasing.md](releasing.md).

## Current release gates

On 14 October 2026, App Store Connect showed no Klyp app record and displayed:

> The Apple Developer Program License Agreement has been updated and needs to
> be reviewed. In order to update your existing apps and submit new apps, the
> Account Holder must review and accept the updated agreement.

The Account Holder must accept the agreement at
<https://developer.apple.com/account>. An agent must not accept it for them.

Before submitting, verify automatic paste, Carbon shortcuts, and the event-tap
fallback in the distribution's sandbox. The current implementation posts
Command+V at the HID event tap and requests Accessibility permission. Neither
compilation nor a signed archive proves that those operations work inside App
Sandbox. File history stores paths rather than persistent security-scoped
bookmarks; verify file restoration and thumbnails after relaunch before
advertising those features in the store listing.

## Build

Generate the candidate project:

```bash
cd macos/KlypApp
xcodegen generate --spec project-app-store.yml
```

The full Xcode installation is required. Set
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` when the machine
defaults to Command Line Tools.

After registering the existing bundle ID and installing its Mac App Store
profile through Apple's API, run from the repository root:

```bash
KLYP_MAS_PROFILE="<installed profile name>" \
KLYP_MAS_KEYCHAIN="$HOME/Library/Keychains/<distribution keychain>.keychain-db" \
bash scripts/build-app-store.sh
```

The keychain must already be unlocked. Use the existing team-wide Mac App
Distribution and Mac Installer Distribution certificates; do not use Developer
ID or separate notarization for a store package. The script checks the archive
signature, sandbox entitlement, absence of debug access, and installer signature.
It writes `dist/mac-app-store/Klyp.pkg` without installing or uploading it.

## Prepared listing

`macos/KlypApp/AppStore/listing/en-US.json` contains draft English app information
and version listing attributes for their respective Apple API resources.
The privacy policy is [privacy.md](privacy.md). Its listing URL becomes
available when this document is published to the repository's default branch.
Recheck the listing against the verified sandbox behavior before uploading.
The draft does not promise automatic paste or persistent file access.

## Local validation on 14 October 2026

All 117 existing tests passed on Xcode 27.0. The unsigned Release archive built
successfully and contains both `arm64` and `x86_64`. Shell syntax, entitlement
plist validation, and documentation discovery passed.

These checks do not validate a running sandbox: an unsigned archive has no
effective sandbox signature. Distribution signing, Apple package validation,
and real sandbox behavior remain outstanding. `guiport doctor` also reports
that the desktop automation tool lacks Accessibility permission on this machine.
Probeport run `20261014T132324309Z-change` exhausted its setup deadline without
completing any checks; it provides no additional runtime verification.

## Finish the release

1. Complete the sandbox behavior checks on a development-signed build without
   replacing an installed copy or changing its Accessibility grant.
2. Register the bundle ID and create a macOS Klyp app record using the signed-in
   agent Chrome and `abx`. Use the existing name and a unique SKU.
3. Keep the app free. Complete category, age rating, territory availability,
   review contact, and App Privacy. The current source has no analytics,
   telemetry, account, or network collection, so Data Not Collected is appropriate.
4. Publish a privacy policy and support URL, prepare accurate listing text,
   and capture real sandboxed app screenshots at Apple's accepted Mac sizes.
5. Validate and upload the signed PKG with `xcrun altool` and the shared
   App Store Connect API key. Wait for a `VALID` processed Mac build.
6. Attach that build, upload the listing and screenshots, and submit through
   Apple's `reviewSubmissions` API. Record the resulting review state here.

Tests use temporary history files. The hosted test app skips clipboard watching,
hotkey registration, and login-item registration.
