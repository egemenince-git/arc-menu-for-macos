#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Ctrl-Esc.app"
DIST="$ROOT/dist"
PROFILE="${CTRL_ESC_NOTARY_PROFILE:-CtrlEscNotary}"
UPLOAD_ZIP="$DIST/Ctrl-Esc-notary-upload.zip"
RELEASE_ZIP="$DIST/Ctrl-Esc.zip"

if [[ ! -d "$APP" ]]; then
    echo "App bundle not found: $APP" >&2
    echo "Build and sign it first with Scripts/build-app.sh." >&2
    exit 1
fi

SIGNATURE="$(codesign --display --verbose=4 "$APP" 2>&1)"
if ! grep -Fq 'Authority=Developer ID Application:' <<<"$SIGNATURE"; then
    echo "The app does not have a Developer ID Application signature." >&2
    echo "Build it with CTRL_ESC_DEVELOPER_IDENTITY set to the installed identity." >&2
    exit 1
fi
if ! grep -Fq 'Runtime Version=' <<<"$SIGNATURE"; then
    echo "The app signature does not enable Hardened Runtime." >&2
    exit 1
fi
if ! grep -Fq 'Timestamp=' <<<"$SIGNATURE"; then
    echo "The app signature has no secure timestamp." >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP"
mkdir -p "$DIST"
rm -f "$UPLOAD_ZIP" "$RELEASE_ZIP"
ditto -c -k --keepParent "$APP" "$UPLOAD_ZIP"

echo "Submitting to Apple notarization using Keychain profile '$PROFILE'..."
xcrun notarytool submit "$UPLOAD_ZIP" --keychain-profile "$PROFILE" --wait

echo "Stapling the accepted ticket to the app..."
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$RELEASE_ZIP"
echo "Notarized and stapled release archive: $RELEASE_ZIP"
