# Contributing

Thanks for helping with Ctrl-Esc. The project is a small native Swift application, so please keep changes focused and follow the existing AppKit/SwiftUI structure.

## Before you start

- Read the [development setup](docs/DEVELOPMENT.md) and [architecture notes](docs/ARCHITECTURE.md).
- Check existing GitHub issues and pull requests before starting work.
- For a feature that changes launcher behavior or settings, describe the intended interaction before making a broad refactor.

## Local workflow

```sh
./Scripts/build-app.sh
open build/Ctrl-Esc.app
```

The build script is the current verification step. There is no automated test target yet. If you add tests, document how to run them and keep them independent of a user’s installed apps, API keys, and personal preferences.

## Code guidelines

- Keep the supported target at macOS 14+ on Apple Silicon unless the maintainers decide to change it.
- Prefer SwiftUI for view composition and AppKit for menu-bar, panel, and macOS integration behavior.
- Keep user-facing state in `LauncherModel`; persist only the preferences described in the architecture document.
- Never persist, print, or commit a TypeSafe API key. Do not add a real key to sample commands, screenshots, logs, or issue reports.
- Keep the JEV catalog payload limited to the fields needed for app-group classification. Update the data-handling documentation if the payload changes.
- Preserve stable app identity by using bundle identifiers where available.
- Keep external API networking in `JevAPIClient.swift`, not in SwiftUI view code.

## Pull requests

Include:

- A concise summary and the user-visible behavior that changed.
- Any settings, persistence, permissions, or external API effects.
- The exact build or manual verification performed.
- Screenshots for visible UI changes, with API keys and personal data removed.

Do not include `build/`, `.build/`, local signing credentials, API keys, or machine-specific session files in a pull request.
