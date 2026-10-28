#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/GHSwitcher.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/GHSwitcher"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GHSwitcher"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --deep -s - "$APP"

echo "Gerado: $APP"
