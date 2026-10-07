#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --arch arm64
BIN_PATH="$(swift build -c release --arch arm64 --show-bin-path)"
APP="$ROOT/build/Ctrl-Esc.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/CtrlEsc" "$APP/Contents/MacOS/CtrlEsc"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>CtrlEsc</string>
    <key>CFBundleIdentifier</key><string>com.ctrl-esc.launcher</string>
    <key>CFBundleName</key><string>Ctrl-Esc</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSArchitecturePriority</key><array><string>arm64</string></array>
    <key>NSAppleEventsUsageDescription</key><string>Ctrl-Esc opens your selected CLI applications in Terminal.</string>
</dict>
</plist>
PLIST
if [[ -n "${CTRL_ESC_DEVELOPER_IDENTITY:-}" ]]; then
    if ! security find-identity -v -p codesigning | grep -Fq "\"$CTRL_ESC_DEVELOPER_IDENTITY\""; then
        echo "Developer ID identity not found in the Keychain: $CTRL_ESC_DEVELOPER_IDENTITY" >&2
        exit 1
    fi
    codesign --force --deep --options runtime --timestamp \
        --entitlements "$ROOT/Scripts/CtrlEsc.entitlements" \
        --sign "$CTRL_ESC_DEVELOPER_IDENTITY" "$APP"
    codesign --verify --deep --strict --verbose=2 "$APP"
    echo "Built and Developer ID signed $APP (Apple Silicon / arm64)"
else
    codesign --force --deep --sign - "$APP"
    echo "Built $APP with an ad-hoc signature (Apple Silicon / arm64)"
fi
