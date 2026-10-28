#!/bin/bash
# Funções compartilhadas por bundle.sh e release.sh.

APP="build/GHSwitcher.app"

version() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist
}

# Monta o .app a partir de um binário já compilado.
assemble_app() {
    local binary="$1"
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cp "$binary" "$APP/Contents/MacOS/GHSwitcher"
    cp Resources/Info.plist "$APP/Contents/Info.plist"
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    for lproj in Resources/*.lproj; do
        cp -R "$lproj" "$APP/Contents/Resources/"
    done
}
