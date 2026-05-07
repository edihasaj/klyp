#!/usr/bin/env bash
set -euo pipefail

# Build a release Klyp.app and stage it under dist/.
# Usage:        ./scripts/build-app.sh
# Signed build: KLYP_SIGN_IDENTITY="Developer ID Application: …" ./scripts/build-app.sh
# Notarize:     KLYP_NOTARY_PROFILE=AC_PASSWORD ./scripts/build-app.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPDIR="$ROOT/macos/KlypApp"
DIST="$ROOT/dist"
SIGN_ID="${KLYP_SIGN_IDENTITY:--}"

cd "$APPDIR"
xcodegen
xcodebuild \
  -scheme Klyp \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="$SIGN_ID" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  | tail -40

APP_PATH="$APPDIR/build/Build/Products/Release/Klyp.app"

# Re-sign deeply with hardened runtime + timestamp when using Developer ID, so
# the embedded Swift dylibs and the app bundle all get the same treatment.
if [[ "$SIGN_ID" != "-" ]]; then
  echo "==> Re-signing $APP_PATH with $SIGN_ID"
  /usr/bin/codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_ID" "$APP_PATH"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  echo "==> Gatekeeper assessment:"
  /usr/sbin/spctl --assess --type execute --verbose "$APP_PATH" || true
fi

mkdir -p "$DIST"
rm -rf "$DIST/Klyp.app" "$DIST/Klyp.app.zip"
cp -R "$APP_PATH" "$DIST/Klyp.app"
( cd "$DIST" && /usr/bin/ditto -c -k --keepParent Klyp.app Klyp.app.zip )

# Optional notarization. Requires a stored notarytool profile:
#   xcrun notarytool store-credentials AC_PASSWORD --apple-id <id> --team-id <team> --password <app-specific>
if [[ -n "${KLYP_NOTARY_PROFILE:-}" ]]; then
  echo "==> Submitting to notarization"
  xcrun notarytool submit "$DIST/Klyp.app.zip" \
    --keychain-profile "$KLYP_NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$DIST/Klyp.app"
  ( cd "$DIST" && rm -f Klyp.app.zip && /usr/bin/ditto -c -k --keepParent Klyp.app Klyp.app.zip )
fi

shasum -a 256 "$DIST/Klyp.app.zip"
echo
echo "✅ Built $DIST/Klyp.app"
