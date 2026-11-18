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
| Windows | Working | [`windows/`](windows/) |

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

## Windows

### Requirements
- Windows 10 or 11 with the ChatGPT desktop app installed from the Microsoft Store.
  (The "Download for Windows" button on chatgpt.com installs the same Store package.)
- Nothing else: the build uses the C# compiler that ships with Windows (.NET Framework 4.x).

### Build
    powershell -ExecutionPolicy Bypass -File windows\build.ps1

This writes `windows\build\Doppel.exe` (about 200 KB, mostly the icon). Put it wherever
you like and pin it to Start or the taskbar. The .exe is unsigned, so SmartScreen may warn
on first run ("More info", then "Run anyway").

### How it works
Doppel for Windows copies nothing and modifies nothing. The Store app cannot be copied,
so `Doppel.exe` is a small launcher (`windows/Doppel.cs`) that:
1. Looks up the current install folder of the ChatGPT Store package (`OpenAI.Codex`) on
   every launch, so ChatGPT updates are picked up automatically. No refresh step is needed.
2. Starts that `ChatGPT.exe` as a second instance with its own profile
   (`%LOCALAPPDATA%\Doppel\profile`) and its own Codex home (`%USERPROFILE%\.codex-doppel`).
3. Stays running invisibly while Doppel is open, giving Doppel's windows the Doppel icon,
   the title "Doppel" and their own taskbar button. It exits when Doppel closes.

Running `Doppel.exe` again while Doppel is open just brings the open window forward.
`Doppel.exe --print` writes the resolved paths to stdout. The environment variables
`DOPPEL_PROFILE` and `DOPPEL_CODEX_HOME` override the data folders.

Installs made under the project's earlier name, DuplicateGPT, keep using their existing
folders (`%LOCALAPPDATA%\DuplicateGPT\profile`, `%USERPROFILE%\.codex-duplicategpt`), so the
second account stays signed in.

### Limitations
- Only one ChatGPT icon can appear in the notification area (near the clock). ChatGPT registers
  it under a fixed ID, so Doppel has no tray icon of its own.
- `codex://` links and the Explorer "Open in Codex" menu go to the original app.
- Starting at login, the Copilot key and Store updates belong to the original app.
- Doppel runs outside the Store package, so features tied to the package may behave
  differently. Voice, computer use, notifications and the Codex sandbox are not yet tested.

### Uninstall
Close Doppel, then delete `Doppel.exe`, `%LOCALAPPDATA%\Doppel` and `%USERPROFILE%\.codex-doppel`.

## Repository layout
- `macos/install.sh`, `macos/launcher.c`: the macOS installer and launcher.
- `macos/Refresh Doppel.command`: one-step refresh after ChatGPT updates.
- `macos/make-logo.swift`: draws the Doppel icon (original artwork).
- `assets/doppel-icon-1024.png`: the rendered icon.
- `windows/Doppel.cs`: the Windows launcher.
- `windows/build.ps1`, `windows/make-icon.ps1`: build the .exe and its icon from `assets/`.

## License

MIT. See [LICENSE](LICENSE).
