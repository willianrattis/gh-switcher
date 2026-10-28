#!/bin/bash
# Monta build/GHSwitcher.app para desenvolvimento (debug, assinatura ad-hoc).
# Para distribuição, use scripts/release.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

CONFIG="${CONFIG:-debug}"
swift build -c "$CONFIG"
assemble_app "$(swift build -c "$CONFIG" --show-bin-path)/GHSwitcher"
codesign --force --deep -s - "$APP"

echo "Gerado: $APP ($CONFIG, ad-hoc)"
