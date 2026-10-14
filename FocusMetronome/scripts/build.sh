#!/bin/bash
# Собирает FocusMetronome.app в build/. Нужен Xcode или Command Line Tools (xcode-select --install).
# Подпись по умолчанию — ad-hoc («Sign to Run Locally»). Для личного Apple ID:
#   SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" ./scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="FocusMetronome"
APP="build/$APP_NAME.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Компиляция (arm64, macOS 14+)"
xcrun swiftc \
  -O -whole-module-optimization \
  -swift-version 5 \
  -target arm64-apple-macos14.0 \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -parse-as-library \
  -module-name "$APP_NAME" \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/$APP_NAME"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Sounds/*.wav "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ Подпись ($SIGN_IDENTITY)"
codesign --force --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"

echo "✓ Готово: $APP"
