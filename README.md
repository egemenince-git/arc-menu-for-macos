# Arc Menu for macOS

Arc Menu for macOS is a native macOS application launcher inspired by GNOME ArcMenu. The app currently appears as **Ctrl-Esc** and opens a searchable, keyboard-driven launcher with **Control-Escape**.

> **Project status:** early development, Apple Silicon only. The source is public; no packaged release is published yet.

## Features

- Search and launch installed macOS applications.
- Browse pinned, recent, and application-group views.
- Optionally launch at login through the macOS Login Items service.
- Show the current macOS account photo in the launcher shortcut panel.
- Add per-application search aliases from the tile context menu.
- Add CLI executables by full path; they appear in the separate **CLI** group and open in Terminal.
- Search for `capture` and launch macOS region capture directly to the clipboard.
- Optionally classify apps into the available groups with a user-provided TypeSafe Jev API key.

## Requirements

- macOS 14 or later
- Apple Silicon (arm64)
- Swift 6 toolchain / Swift Package Manager (for example, the Xcode Command Line Tools)

There are no third-party Swift package dependencies.

## Build and run

```sh
./Scripts/build-app.sh
open build/Ctrl-Esc.app
```

The script builds an arm64 release binary, creates `build/Ctrl-Esc.app`, and applies an ad-hoc code signature for local use. Generated build products are ignored by Git.

To sign with an installed Developer ID Application identity, set the identity name for that invocation:

```sh
CTRL_ESC_DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
```

The Developer ID build enables Hardened Runtime, applies a secure timestamp, and includes the Apple Events entitlement required for CLI apps opened in Terminal. Use `./Scripts/notarize-app.sh` to submit a signed build, staple the accepted ticket, validate it, and create `dist/Ctrl-Esc.zip`. See the [distribution notes](docs/DISTRIBUTION.md) before preparing a release.

## Use

1. Launch Ctrl-Esc. It appears as a menu bar item without opening a regular window.
2. Press **Control-Escape** or click the menu bar item to open the launcher.
3. Search for an app and press Return or select its tile. Press Escape or click elsewhere to dismiss the launcher.
4. Right-click an app tile to pin/unpin it, edit search aliases, or reveal it in Finder.
5. Open **Settings** from the launcher’s gear button to add CLI executables or configure Jev.

### CLI applications

In Settings → **CLI Applications**, enter the absolute path to an executable and select **Add CLI App**. The command appears under **CLI** and runs in Terminal when selected. macOS may ask Ctrl-Esc for permission to control Terminal.

### Jev sorting and data

In Settings → **USE AI**, enter a TypeSafe API key and choose **Verify API Key**. On success, **Sort Apps With JEV** becomes available. The key remains in memory only and is not written to preferences. Sorting sends the scanned app names, bundle identifiers, and application-group names to TypeSafe’s API; returned app-to-group assignments are saved locally. Review [JEV data handling](docs/ARCHITECTURE.md#jev-app-group-sorting) before using the feature.

## Project documentation

- [Development setup](docs/DEVELOPMENT.md)
- [Architecture and data flow](docs/ARCHITECTURE.md)
- [Contributor handoff](docs/HANDOFF.md)
- [Contributing](CONTRIBUTING.md)
- [Security and disclosure](SECURITY.md)
- [Distribution readiness plan](docs/DISTRIBUTION.md)

## License

No license has been selected yet. Until a `LICENSE` file is added, do not assume that the source is licensed for reuse or redistribution.
