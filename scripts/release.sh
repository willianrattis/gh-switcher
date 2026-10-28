#!/bin/bash
# Gera a versão de distribuição: binário universal, assinatura Developer ID,
# notarização, staple, .zip, .dmg e checksums em build/release/.
#
# Variáveis:
#   SIGN_IDENTITY     identidade de assinatura (padrão: Developer ID Application do time abaixo)
#   TEAM_ID           padrão: 5DN63BVFHM
#   NOTARY_PROFILE    perfil do notarytool no Keychain (padrão: gh-switcher)
#   NOTARY_KEY_PATH / NOTARY_KEY_ID / NOTARY_ISSUER   alternativa ao perfil (usada no CI)
#   SKIP_NOTARIZE=1   só assina, sem notarizar (teste rápido)
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib.sh

TEAM_ID="${TEAM_ID:-5DN63BVFHM}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Willian Santa Rosa Rattis ($TEAM_ID)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-gh-switcher}"
VERSION="$(version)"
OUT="build/release"
ZIP="$OUT/GHSwitcher-$VERSION.zip"
DMG="$OUT/GHSwitcher-$VERSION.dmg"

step() { printf '\n==> %s\n' "$*"; }

notarize() {
    local file="$1"
    if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
        echo "SKIP_NOTARIZE=1: pulando notarização de $file"
        return
    fi
    if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
        xcrun notarytool submit "$file" --wait \
            --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER"
    else
        xcrun notarytool submit "$file" --wait --keychain-profile "$NOTARY_PROFILE"
    fi
}

step "Testes"
swift test

step "Build universal (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/GHSwitcher"
lipo -info "$BIN"

step "Montando $APP ($VERSION)"
assemble_app "$BIN"

step "Assinando com: $SIGN_IDENTITY"
codesign --force --options runtime --timestamp \
    --entitlements Resources/GHSwitcher.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -rf "$OUT"
mkdir -p "$OUT"

step "Notarizando o app"
ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
notarize "$OUT/notarize.zip"
rm "$OUT/notarize.zip"
if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
fi

step "Gerando $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

step "Gerando $DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "GH Switcher" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
notarize "$DMG"
if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    xcrun stapler staple "$DMG"
fi

step "Checksums"
(cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" | tee SHA256SUMS.txt)

if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    step "Gatekeeper"
    spctl -a -vvv -t exec "$APP"
    spctl -a -vvv -t open --context context:primary-signature "$DMG"
fi

echo
echo "Pronto: $OUT"
