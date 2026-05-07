#!/usr/bin/env bash
set -euo pipefail

# Build a release Klyp.app and stage it under dist/.
# Usage:  ./scripts/build-app.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPDIR="$ROOT/macos/KlypApp"
DIST="$ROOT/dist"

cd "$APPDIR"
xcodegen
xcodebuild \
  -scheme Klyp \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  | tail -40

mkdir -p "$DIST"
APP_PATH="$APPDIR/build/Build/Products/Release/Klyp.app"
rm -rf "$DIST/Klyp.app" "$DIST/Klyp.app.zip"
cp -R "$APP_PATH" "$DIST/Klyp.app"
( cd "$DIST" && /usr/bin/ditto -c -k --keepParent Klyp.app Klyp.app.zip )

shasum -a 256 "$DIST/Klyp.app.zip"
echo
echo "✅ Built $DIST/Klyp.app"
