# Security Policy

## Design principles

- GH Switcher never reads, stores, logs or displays GitHub tokens.
- All credentials are managed by the GitHub CLI and kept in the macOS Keychain.
- The app only runs `gh auth status --json hosts`, `gh auth switch`, and, on explicit user
  action, `gh auth login --web` and `gh auth logout`.
- It never runs `gh auth token`, `gh auth refresh` or `gh auth setup-git`.

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please **do not open a public issue**. Use
[GitHub private vulnerability reporting](https://github.com/willianrattis/gh-switcher/security/advisories/new)
with steps to reproduce and the affected version. You will get a reply within 7 days.
