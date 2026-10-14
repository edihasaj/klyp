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
/usr/bin/python3 - "$OUTPUT/signed-entitlements.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as stream:
    entitlements = plistlib.load(stream)
assert entitlements.get("com.apple.security.app-sandbox") is True, "Sandbox entitlement missing"
assert not entitlements.get("com.apple.security.get-task-allow"), "Debug entitlement present"
assert entitlements.get("com.apple.application-identifier") == "T8J48M4QVY.com.edihasaj.klyp"
PY
productbuild --component "$APP" /Applications \
  --sign "${KLYP_MAS_INSTALLER_IDENTITY:-3rd Party Mac Developer Installer: Applifyer, LLC (T8J48M4QVY)}" \
  --keychain "$KLYP_MAS_KEYCHAIN" "$OUTPUT/Klyp.pkg"
pkgutil --check-signature "$OUTPUT/Klyp.pkg"
printf 'Signed store package: %s\n' "$OUTPUT/Klyp.pkg"
