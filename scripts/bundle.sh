#!/usr/bin/env bash
# Builds Crossnest and wraps it in build/Crossnest.app
# Usage: scripts/bundle.sh [release|debug]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Crossnest.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Crossnest" "$APP/Contents/MacOS/Crossnest"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with a real certificate when one exists, so macOS remembers permissions
# (Automation etc.) across rebuilds. Override with SIGN_IDENTITY="...".
# Falls back to ad-hoc signing, which macOS treats as a new app on every build.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 -E '"(Apple Development|Developer ID Application)' | sed -E 's/.*"(.*)"/\1/' || true)}"
if [[ -n "$IDENTITY" ]]; then
  echo "Signing with: $IDENTITY"
  codesign --force --options runtime --sign "$IDENTITY" "$APP"
else
  echo "No signing certificate found — using ad-hoc signing (permissions reset on each rebuild)."
  codesign --force --sign - "$APP"
fi

echo "Built $APP — run: open $APP"
