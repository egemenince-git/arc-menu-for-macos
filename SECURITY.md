# Security policy

Arc Menu for macOS is under active development and does not yet publish supported release versions.

## Reporting a vulnerability

Do not post API keys, passwords, tokens, or other credentials in a public issue. Use GitHub's private vulnerability reporting for this repository when it is enabled; otherwise, contact the maintainer through the email listed in the app's Settings screen.

## API keys and user data

- Never commit a TypeSafe API key or include one in screenshots, logs, sample files, or issue reports.
- Jev keys are supplied by the user, held in memory only, and sent as bearer credentials over HTTPS.
- When the user invokes Jev sorting, the app sends installed app display names, bundle identifiers, app-group names, and classification questions to TypeSafe. It does not send app paths or manually added CLI paths.
- Jev’s returned app-group assignments are stored locally in UserDefaults.

For details, see [architecture and data flow](docs/ARCHITECTURE.md#jev-app-group-sorting).
