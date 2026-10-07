# Distribution notes

This document describes the direct-download release workflow. Version [0.1.0 is published on GitHub Releases](https://github.com/egemenince-git/arc-menu-for-macos/releases/tag/v0.1.0) for macOS 14 or later on Apple Silicon.

## Build and verify locally

The project targets Apple Silicon and macOS 14 or later. A local build can be created with:

```sh
./Scripts/build-app.sh
open build/Ctrl-Esc.app
```

Without a signing identity, the script applies an ad-hoc signature suitable for local development. For distribution, install a Developer ID Application certificate in the login Keychain, then set the matching identity for the build:

```sh
CTRL_ESC_DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 build/Ctrl-Esc.app
codesign --display --verbose=4 build/Ctrl-Esc.app
```

The Developer ID build uses Hardened Runtime, a secure timestamp, and the Apple Events entitlement required to launch CLI apps in Terminal.

## Notarize

Set up `notarytool` credentials in the local Keychain using an app-specific password. Do not put credentials or signing keys in the repository. Apple documents the current credential setup and notarization flow in its [notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

After configuring a local Keychain profile, run:

```sh
./Scripts/notarize-app.sh
```

The script verifies the signature, submits the app to Apple's notary service, waits for the result, staples and validates the accepted ticket, and creates `dist/Ctrl-Esc.zip`.

## Before publishing a release

- Preserve the MIT License and copyright notice in distributed copies.
- Confirm product name, copyright, bundle identifier, and versioning policy.
- Add a production app icon and verify bundle metadata.
- Document clean install and uninstall steps.
- Test the quarantined notarized archive on a clean Apple Silicon account without prior permissions or app preferences.
- Verify first launch, menu-bar behavior, Control-Escape, aliases, CLI/Terminal consent, capture, Jev key verification, and app-group sorting.
- Document privacy disclosures for the data sent to TypeSafe and provide a support and security contact path.
- Publish release notes, supported macOS version and architecture, archive checksum, and known issues.
- If release automation is added, store signing and notarization credentials in a protected secret store.

The Mac App Store would require a separate review of sandbox constraints, including app enumeration, Carbon global hotkeys, Terminal Apple Events, user-selected executable paths, and network access.
