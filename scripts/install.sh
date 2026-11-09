#!/usr/bin/env bash
# Builds a release Crossnest.app and installs it to /Applications (quitting a running copy first).
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/bundle.sh release

if pgrep -f "/Applications/Crossnest.app/Contents/MacOS/Crossnest" >/dev/null; then
  echo "Quitting running Crossnest…"
  osascript -e 'tell application id "dev.tdodd.Crossnest" to quit' || true
  sleep 1
fi

rm -rf /Applications/Crossnest.app
ditto build/Crossnest.app /Applications/Crossnest.app
codesign --verify --strict /Applications/Crossnest.app
echo "Installed /Applications/Crossnest.app"
