# Contributor handoff

Arc Menu for macOS is a native macOS menu-bar launcher inspired by GNOME ArcMenu. The application is currently named Ctrl-Esc in its bundle and UI. It targets Apple Silicon and macOS 14 or later.

## Get started

Read the [development setup](DEVELOPMENT.md), [architecture](ARCHITECTURE.md), [contributing guide](../CONTRIBUTING.md), and [security policy](../SECURITY.md). Build and launch locally with:

```sh
./Scripts/build-app.sh
open build/Ctrl-Esc.app
```

The app stays in the menu bar. Press Control-Escape to open the launcher.

## Main code areas

- `Sources/CtrlEsc/main.swift`: app lifecycle, menu-bar item, and hotkey setup.
- `Sources/CtrlEsc/GlobalHotKeyMonitor.swift`: Control-Escape registration through Carbon.
- `Sources/CtrlEsc/MenuPanelController.swift` and `LauncherMenuView.swift`: launcher panel, search, app groups, account photo, and shortcut panel.
- `Sources/CtrlEsc/MacOSAccountPhoto.swift`: reads the current local macOS account photo, with a generic fallback.
- `Sources/CtrlEsc/LauncherModel.swift`: app catalog, groups, aliases, pinned/recent apps, CLI entries, and preferences.
- `Sources/CtrlEsc/SettingsView.swift`: Launch at Login, CLI app management, Jev settings, and developer credit.
- `Sources/CtrlEsc/JevAPIClient.swift`: TypeSafe Jev API integration.
- `Scripts/build-app.sh` and `Scripts/notarize-app.sh`: local app packaging and optional Developer ID notarization.

## Important behavior

- Installed applications are identified by bundle path so apps with duplicate bundle identifiers remain distinct.
- Launch at Login uses `SMAppService.mainApp`.
- CLI apps are launched in Terminal through Apple Events; keep the usage description and `Scripts/CtrlEsc.entitlements` aligned if this changes.
- Jev API keys are held in memory only. Sorting sends app display names, bundle identifiers, and app-group names to TypeSafe; returned assignments are stored locally. See [data flow](ARCHITECTURE.md#jev-app-group-sorting).

## Known gaps

- There is no automated test target or CI workflow yet.
- The app has no icon or updater.
- There is no packaged GitHub release yet. See the [distribution notes](DISTRIBUTION.md) before preparing one.
- The project uses the MIT License; preserve its copyright and license notice when redistributing copies.
