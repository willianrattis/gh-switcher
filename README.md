# GH Switcher

**Switch your GitHub CLI account from the macOS menu bar, with one click.**

GH Switcher is a native menu bar app for people who juggle more than one GitHub account
(personal and work, for example) in the [GitHub CLI](https://cli.github.com). It lists the
accounts known to `gh` and runs `gh auth switch` for you, in a panel that looks and feels
like macOS Control Center.

🇧🇷 [Leia em português](README.pt-BR.md)

<!-- docs/panel.png and docs/demo.gif are added before the first release -->

## Features

- **One-click switching** of the active `gh` account, per host (github.com and GitHub Enterprise).
- **Liquid Glass panel** in the style of Control Center; no Dock icon.
- **Stays in sync** with the terminal: refreshes when opened and every 60 seconds.
- **Add and remove accounts** without the terminal: browser sign-in with a one-time code.
- **Optional login in the menu bar**, notifications, Open at Login.
- **English and Portuguese (Brazil).**

## Install

```bash
brew trust willianrattis/tap
brew install --cask willianrattis/tap/gh-switcher
```

`brew trust` is required by Homebrew for third-party taps. Homebrew also installs the GitHub CLI if you don't have it. Then open **GH Switcher** and,
if needed, click **Add account**.

Prefer a download? Get the `.dmg` from the
[latest release](https://github.com/willianrattis/gh-switcher/releases/latest) and drag the
app to Applications. Releases are signed with a Developer ID and notarized by Apple.

**Requirements:** macOS 13 or later (Liquid Glass on macOS 26+), Apple silicon or Intel.

## Security and privacy

- GH Switcher **never reads, stores or displays tokens**. Credentials stay with the GitHub
  CLI, in the macOS Keychain.
- It only runs `gh auth status --json hosts`, `gh auth switch`, `gh auth login --web` and
  `gh auth logout`, the last two only when you ask. The `token` field returned by
  `gh auth status` is never decoded.
- During sign-in, the only thing taken from `gh`'s output is the one-time device code.
  Nothing is logged.
- No analytics, no telemetry, no network calls besides GitHub avatars and what `gh` itself does.

See [SECURITY.md](SECURITY.md) to report a vulnerability.

## Usage tips

**Commit identity per folder.** Switching the `gh` account does not change git's
`user.name`/`user.email`. Use `includeIf` in `~/.gitconfig`:

```ini
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work
```

**Custom gh location.** GH Switcher looks for `gh` in Settings, `/opt/homebrew/bin`,
`/usr/local/bin` and your login shell's `PATH`.

## Build from source

```bash
swift build && swift test
scripts/bundle.sh          # build/GHSwitcher.app (debug, ad-hoc signed)
open build/GHSwitcher.app
```

`scripts/release.sh` builds the universal, signed and notarized release (maintainers only).

## License

[FSL-1.1-MIT](LICENSE.md) (Functional Source License). In short: you can use, study, modify
and share GH Switcher for any purpose **except** offering a competing commercial product.
**Each release automatically becomes MIT two years after it's published.**

GH Switcher is not affiliated with or endorsed by GitHub, Inc. GitHub and the GitHub logo
are trademarks of GitHub, Inc.

## Support

If GH Switcher saves you time, consider
[sponsoring the project](https://github.com/sponsors/willianrattis). ❤️
