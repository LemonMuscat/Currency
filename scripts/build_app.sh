#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/CurrencyPanel.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"

cd "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MODULE_CACHE"
mkdir -p "$ROOT_DIR/build"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

clang \
  -fobjc-arc \
  -fmodules \
  -fmodules-cache-path="$MODULE_CACHE" \
  -DSTANDALONE_RUNTIME=1 \
  -mmacosx-version-min=13.0 \
  -framework Cocoa \
  -o "$MACOS_DIR/CurrencyPanelRuntime" \
  "$ROOT_DIR/Sources/CurrencyPanel/main.m"

clang \
  -mmacosx-version-min=13.0 \
  -framework Cocoa \
  -o "$MACOS_DIR/CurrencyPanelLauncher" \
  "$ROOT_DIR/Sources/Launcher/main.c"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
printf "APPLCURR" > "$CONTENTS_DIR/PkgInfo"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable CurrencyPanelLauncher" "$CONTENTS_DIR/Info.plist" >/dev/null

codesign --force --deep --sign - "$APP_DIR" >/dev/null
touch "$APP_DIR"

echo "Built $APP_DIR"
