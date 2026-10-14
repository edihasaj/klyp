---
summary: Klyp's native Mac App Store edition, signing, screenshots, and submission.
read_when:
  - Shipping Klyp to the Mac App Store
  - Changing sandbox entitlements, clipboard access, or release signing
---

# Mac App Store

Klyp's native Mac platform uses App Store Connect record `6822758532`, bundle ID
`com.edihasaj.klyp`, and Applifyer team `T8J48M4QVY`. Version **1.0.0 (25)**
was validated and uploaded on **14 October 2026**. Apple reports the build
as `VALID`. The review submission is **WAITING_FOR_REVIEW**, confirmed through
Apple's API on the same day. The release will publish automatically after approval.

The store title is **Klyp: Clipboard History** because Apple reported that
the exact name “Klyp” was already in use. The installed app remains named Klyp.
It is free in all 175 territories, with automatic availability in new
territories. App Privacy is published as **Data Not Collected**.

`macos/KlypApp/project-app-store.yml` overlays the direct-download project.
It builds for Intel and Apple Silicon on macOS 14+, enables App Sandbox and
read-only user-selected file access, and defines `MAC_APP_STORE`. History,
settings, and image caches stay in the local sandbox. No network entitlement,
external updater, account, or payment service is included.

The store edition registers launch at login only after the user enables it
in Settings. Its picker explains the permission-free workflow: choose an
item, then press Command+V in the destination app. Accessibility is optional
for automatic paste and the event-tap shortcut fallback. It is offered
through the picker notice and menu bar menu rather than an alert at launch.
Automatic paste posts Command+V within the user's session.

The direct-download release process remains in [releasing.md](releasing.md).
The separate store version and build do not change that edition's version.

## Signing

The shared Mac App Distribution and Mac Installer Distribution certificates
are in the dedicated `chirpgo-mas.keychain-db`. The development certificate's
display name contains its developer identifier `464627D7HL`; its organizational
unit and provisioning profiles correctly belong to team `T8J48M4QVY`.

Installed profiles:

| Purpose | Profile |
| --- | --- |
| Local signed sandbox tests | Klyp Mac Development 2026-10 |
| Store distribution | Klyp Mac App Store 2026-10 |

Profiles live in `~/Library/Developer/Xcode/UserData/Provisioning Profiles`.
The development profile uses the Mac Studio's **Provisioning UDID**.

The machine's private `~/.profile` supplies the existing keychain password.
Unlock that dedicated keychain without printing its password. Credentials
come from the shared `Apple Admin API Key` in 1Password, accessed inside tmux.
Keep the private API key workspace out of the repository.

## Verify and release

1. Bump the store build number in `project-app-store.yml`.
2. Generate the store project and run the full hosted test suite:

   ```bash
   cd macos/KlypApp
   xcodegen generate --spec project-app-store.yml
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
     xcodebuild -project KlypAppStore.xcodeproj -scheme Klyp \
       -configuration Debug -destination platform=macOS \
       -derivedDataPath build/store-tests -resultBundlePath build/store-tests.xcresult \
       OTHER_CODE_SIGN_FLAGS="--keychain $HOME/Library/Keychains/chirpgo-mas.keychain-db" test
   ```

3. Run `scripts/build-app-store.sh` from the repository root:

   ```bash
   KLYP_MAS_PROFILE="Klyp Mac App Store 2026-10" \
   KLYP_MAS_KEYCHAIN="$HOME/Library/Keychains/chirpgo-mas.keychain-db" \
     bash scripts/build-app-store.sh
   ```

   The script archives, verifies signatures and sandbox entitlements, rejects
   debug access, and signs `dist/mac-app-store/Klyp.pkg`. Store packages use
   Apple's store validation rather than Developer ID notarization.

4. Validate and upload the PKG with `xcrun altool`, using the API key workspace.
   Wait for a `VALID` processed Mac build.
5. Export the native screenshot attachments with `xcresulttool export attachments`
   and run `scripts/frame-store-screenshots.py` through `uv --with pillow`.
   Inspect the resulting 1440×900 images before upload. Listing attributes
   and screenshots live under `macos/KlypApp/AppStore/listing`.
6. Use the private `~/Projects/manager/scripts/klyp/store-release.py` to attach
   screenshots, review details, and the processed build. Pass `--submit` to
   submit through Apple's review API, then `--state` to read back the result.

The public privacy policy is [privacy.md](privacy.md), published on GitHub.
App Privacy is managed in the signed-in agent Chrome with `abx`; the public
Apple API handles listings, pricing, availability, and review submission.

## Verification evidence

All **119 tests** passed in the development-signed App Sandbox on Xcode 27.0.
The direct-download project's **117 tests** also passed after the store changes.
They verify the running signature's sandbox entitlement, container storage,
history persistence, clipboard restoration, removal of rich-text formatting,
and native screen rendering. Carbon shortcut registration and re-registration
succeeded. Hosted tests do not register login items or watch the user's clipboard,
and their history stores use temporary files.

Both architecture slices compiled in the distribution archive. Its application
identifier and sandbox entitlement were checked, debug access was absent, and
both app and installer signatures verified. Apple package validation and upload
completed without errors.

Accessibility was not granted to the test build, so automatic paste into another
app and the granted-permission event-tap fallback were not exercised. Physical
shortcut delivery and persistent access to files copied from other apps also
remain outside this test evidence. The listing does not promise persistent file
access. The clipboard restoration workflow works without Accessibility.

Local evidence is under `/tmp/verify/klyp-mac-app-store`, including
`signed-final.xcresult`, `direct-final.xcresult`, validation and upload logs.
