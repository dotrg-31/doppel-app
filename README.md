# Doppel

Run a second, fully separate copy of the ChatGPT desktop app on macOS and Windows, with
its own account, data and settings.

**Unofficial.** Doppel is an independent tool. It is not affiliated with, endorsed by, or
supported by OpenAI. "ChatGPT" is a trademark of OpenAI.

**Use at your own risk.** Running a modified second copy of the ChatGPT app may be against
OpenAI's terms of use. Read them and decide for yourself before using Doppel. Doppel is
meant for personal use on your own computer with accounts that are yours.

This repository contains only Doppel's own scripts, launcher source, artwork and docs. It
does not include any of OpenAI's files. Doppel works on the copy of ChatGPT that you
installed yourself, and never modifies it.

| Platform | Status | Folder |
|---|---|---|
| macOS | Working | [`macos/`](macos/) |
| Windows | Source coming soon | `windows/` |

## macOS

### Requirements
- macOS 14 or later on an APFS volume, with the ChatGPT desktop app in `/Applications`
- Xcode command line tools (`xcode-select --install`)

### Install
    ./macos/install.sh

Then open `~/Applications/Doppel.app` and sign in with your second account.

### What the installer does
1. Clones `/Applications/ChatGPT.app` to `~/Applications/Doppel.app` (an APFS clone, so it
   uses almost no extra disk). The original app is only read, never modified.
2. Gives the copy its own identity (name, icon, bundle ID `com.rgdevelopment.doppel`) and
   removes its link/file-type claims and its self-updater.
3. Adds a small launcher (`macos/launcher.c`) that starts the copy with its own profile
   (`~/Library/Application Support/Doppel`) and its own Codex home (`~/.codex-doppel`),
   and hands the `codex://` link scheme back to the original app.
4. Signs the copy locally (ad-hoc), dropping entitlements that only OpenAI's Apple team
   may use (push notifications, universal links, app groups, shared keychain group).

Installs made under the project's earlier name, DuplicateGPT, keep their old bundle ID and
data folders (`~/Library/Application Support/DuplicateGPT`, `~/.codex-duplicategpt`), so the
second account stays signed in.

### After ChatGPT updates
Double-click `macos/Refresh Doppel.command` (or run `macos/install.sh` again). It takes
about 20 seconds and keeps your Doppel login and data. Doppel does not update itself;
until it is refreshed it keeps running the older version.

### Limitations of a locally signed copy
- No push notifications.
- `codex://` links and connector sign-in callbacks go to the original app.
- Features that check OpenAI's signature or use its app group (computer-use helper,
  browser-extension pairing) may refuse the copy.
- macOS asks again for microphone, screen-recording and accessibility permissions, and
  may ask again after each refresh.
- Global shortcuts may clash with the original app's.

### Uninstall
Delete `~/Applications/Doppel.app`, `~/Library/Application Support/Doppel`, `~/.codex-doppel`
and run `defaults delete com.rgdevelopment.doppel`.

## Repository layout
- `macos/install.sh`, `macos/launcher.c`: the macOS installer and launcher.
- `macos/Refresh Doppel.command`: one-step refresh after ChatGPT updates.
- `macos/make-logo.swift`: draws the Doppel icon (original artwork).
- `assets/doppel-icon-1024.png`: the rendered icon.
- `windows/`: the Windows build (not yet published here).

## License

MIT. See [LICENSE](LICENSE).
