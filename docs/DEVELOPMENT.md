# Development setup

## Toolchain

- Apple Silicon Mac
- macOS 14 or later
- Swift 6 / Swift Package Manager
- Xcode Command Line Tools or Xcode

Check the active toolchain with:

```sh
swift --version
xcode-select -p
```

## Build

From the repository root:

```sh
swift build -c debug --arch arm64
./Scripts/build-app.sh
```

The first command builds the Swift package. The script builds the release executable and assembles the app bundle at `build/Ctrl-Esc.app`. It uses an ad-hoc signature for local development; it does not produce a Developer ID-signed or notarized release.

If a Developer ID Application identity is installed in the current Keychain, you can make a Developer ID-signed build without storing the identity name in the repository:

```sh
CTRL_ESC_DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
```

The script checks that the identity is available, enables Hardened Runtime, adds a secure timestamp, includes the Apple Events entitlement needed to automate Terminal, and verifies the resulting code signature. This does not notarize or package the app.

Launch the app with:

```sh
open build/Ctrl-Esc.app
```

The app is an accessory/menu-bar process. It does not open a normal window on launch. Use **Control-Escape** or click its menu bar icon. Settings are opened from the launcher’s gear button.

## Build outputs and cleanup

- `.build/` — SwiftPM intermediate files
- `build/Ctrl-Esc.app` — locally assembled application bundle

Both paths are ignored by Git. To rebuild, run `./Scripts/build-app.sh`; it replaces the app bundle in `build/`.

## Debugging integrations

### Global shortcut

The default shortcut is registered with Carbon’s `RegisterEventHotKey`. It currently uses Control-Escape and has no settings UI for rebinding it.

### CLI applications

CLI paths are checked for executable permission. Selecting one asks Terminal to run it in a shell session using Apple Events. macOS may show a privacy prompt. The bundle’s `NSAppleEventsUsageDescription` explains why Ctrl-Esc needs this permission.

Developer ID builds also need `com.apple.security.automation.apple-events` in the entitlements file so Hardened Runtime permits the app to request user authorization for Apple Events.

### TypeSafe Jev

Key verification calls `GET https://api.typesafe.ai/v1/models`; sorting calls `POST https://api.typesafe.ai/v1/systemone`. Both use `Authorization: Bearer …`. The model is discovered from the key’s model list. See [architecture and data flow](ARCHITECTURE.md#jev-app-group-sorting) for what the app sends and stores.

To troubleshoot a user-reported API failure, ask for the HTTP status and redacted error text. Never ask for the full API key.

## Current gaps

- No automated test target or CI workflow is configured.
- The 0.1.0 release archive is published on GitHub. There is no app icon, updater, or automated release workflow yet.
- The build script is arm64-only and ad-hoc signs the app.
- See the [distribution readiness plan](DISTRIBUTION.md) before preparing a public build.
