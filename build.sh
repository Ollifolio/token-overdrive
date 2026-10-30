#!/bin/zsh
set -eu
cd "$(dirname "$0")"
app='Token Overdrive.app'
mkdir -p "$app/Contents/MacOS"
mkdir -p "$app/Contents/Resources"
cp 'Resources/Info.plist' "$app/Contents/Info.plist"
cp 'Resources/Dosis[wght].ttf' "$app/Contents/Resources/Dosis[wght].ttf"
cp -R 'Resources/Gallery' "$app/Contents/Resources/"
cp -R 'Resources/Splash' "$app/Contents/Resources/"
cp 'Resources/TokenOverdrive.icns' "$app/Contents/Resources/TokenOverdrive.icns"
cp 'Resources/TokenOverdrive-Wordmark.svg' "$app/Contents/Resources/TokenOverdrive-Wordmark.svg"
swiftc -O native/TokenTacho.swift -o "$app/Contents/MacOS/TokenTacho" -framework SwiftUI -framework AppKit -framework AVFoundation -module-cache-path /private/tmp/token-tacho-module-cache
codesign --force --sign - "$app"
"$app/Contents/MacOS/TokenTacho" --self-test
