#!/usr/bin/env bash
set -euo pipefail

# Archive the sandboxed store edition; do not replace the installed app.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${KLYP_MAS_OUTPUT:-$ROOT/dist/mac-app-store}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -z "${KLYP_MAS_PROFILE:-}" ]]; then
  echo "Set KLYP_MAS_PROFILE to the installed Mac App Store provisioning profile." >&2
  exit 1
fi
if [[ -z "${KLYP_MAS_KEYCHAIN:-}" ]]; then
  echo "Set KLYP_MAS_KEYCHAIN to the unlocked distribution-signing keychain." >&2
  exit 1
fi

mkdir -p "$OUTPUT"
cd "$ROOT/macos/KlypApp"
xcodegen generate --spec project-app-store.yml
xcodebuild \
  -project KlypAppStore.xcodeproj -scheme Klyp -configuration Release \
  -destination generic/platform=macOS -derivedDataPath "$OUTPUT/derived" \
  -archivePath "$OUTPUT/Klyp.xcarchive" \
  KLYP_MAS_PROFILE="$KLYP_MAS_PROFILE" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KLYP_MAS_KEYCHAIN" archive

APP="$OUTPUT/Klyp.xcarchive/Products/Applications/Klyp.app"
codesign --verify --deep --strict "$APP"
codesign -d --entitlements :- "$APP" > "$OUTPUT/signed-entitlements.plist"
[[ "$(plutil -extract com.apple.security.app-sandbox raw "$OUTPUT/signed-entitlements.plist")" == true ]]
if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' \
  "$OUTPUT/signed-entitlements.plist" 2>/dev/null | grep -q true; then
  echo "Distribution archive contains the debug entitlement." >&2
  exit 1
fi
productbuild --component "$APP" /Applications \
  --sign "${KLYP_MAS_INSTALLER_IDENTITY:-3rd Party Mac Developer Installer: Applifyer, LLC (T8J48M4QVY)}" \
  --keychain "$KLYP_MAS_KEYCHAIN" "$OUTPUT/Klyp.pkg"
pkgutil --check-signature "$OUTPUT/Klyp.pkg"
printf 'Signed store package: %s\n' "$OUTPUT/Klyp.pkg"
