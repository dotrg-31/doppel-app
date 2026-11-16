#!/bin/bash
# Builds ~/Applications/Doppel.app: a private copy of the installed ChatGPT desktop app
# with its own identity, icon, data folder and Codex home, so a second account can be signed in.
#
# - /Applications/ChatGPT.app and its data are only read, never modified.
# - Re-run this after ChatGPT updates to bring the copy to the same version.
#   The copy's login and data are kept (they live outside the app bundle).
set -euo pipefail
cd "$(dirname "$0")"

SRC="/Applications/ChatGPT.app"
APP="$HOME/Applications/Doppel.app"
BUNDLE_ID="com.rgdevelopment.doppel"
USER_DATA="$HOME/Library/Application Support/Doppel"
CODEX_DIR="$HOME/.codex-doppel"
# Installs made before the rename (when the app was called DuplicateGPT) keep their identity
# and data folders, so the second account stays signed in and macOS permissions carry over.
LEGACY_APP="$HOME/Applications/DuplicateGPT.app"
if [ -d "$HOME/Library/Application Support/DuplicateGPT" ]; then
  BUNDLE_ID="com.rgdevelopment.duplicategpt"
  USER_DATA="$HOME/Library/Application Support/DuplicateGPT"
fi
[ -d "$HOME/.codex-duplicategpt" ] && CODEX_DIR="$HOME/.codex-duplicategpt"
PB=/usr/libexec/PlistBuddy
WORK="$(mktemp -d)"

[ -d "$SRC" ] || { echo "ChatGPT.app not found in /Applications"; exit 1; }

echo "Stopping Doppel if it is running…"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
sleep 1
pkill -f "$APP/Contents/" 2>/dev/null || true
if [ -d "$LEGACY_APP" ]; then
  pkill -f "$LEGACY_APP/Contents/" 2>/dev/null || true
  rm -rf "$LEGACY_APP"   # replaced by Doppel.app; its data folders are kept
fi

echo "Copying ChatGPT.app (APFS clone, uses almost no extra disk)…"
mkdir -p "$HOME/Applications"
rm -rf "$APP"
cp -c -R "$SRC" "$APP" 2>/dev/null || cp -R "$SRC" "$APP"
xattr -cr "$APP" 2>/dev/null || true
C="$APP/Contents"

echo "Applying Doppel identity…"
plutil -convert xml1 "$C/Info.plist"
$PB -c "Set :CFBundleIdentifier $BUNDLE_ID" \
    -c "Set :CFBundleName Doppel" \
    -c "Set :CFBundleDisplayName Doppel" \
    -c "Set :CFBundleExecutable Doppel" \
    -c "Set :CFBundleIconFile Doppel.icns" "$C/Info.plist"
# Links, file types and updates stay with the original app.
for key in CFBundleIconName CFBundleURLTypes CFBundleDocumentTypes UTExportedTypeDeclarations \
           UTImportedTypeDeclarations SUFeedURL NSUserActivityTypes; do
  $PB -c "Delete :$key" "$C/Info.plist" 2>/dev/null || true
done
# Isolation: a small launcher starts the copied app with its own Chromium profile and its
# own Codex home (both are settings the app itself supports).
clang -O2 -framework CoreServices -o "$C/MacOS/Doppel" launcher.c
mkdir -p "$USER_DATA" "$CODEX_DIR"

# Icon
ICONSET="$WORK/AppIcon.iconset"; mkdir -p "$ICONSET"
for sz in 16 32 128 256 512; do
  swift make-logo.swift $sz "$ICONSET/icon_${sz}x${sz}.png"
  swift make-logo.swift $((sz*2)) "$ICONSET/icon_${sz}x${sz}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$C/Resources/Doppel.icns"

# The copy must never self-update (an update would replace it with a plain ChatGPT copy).
# It is refreshed by re-running this script instead.
SP="$C/Frameworks/Sparkle.framework/Versions/B"
rm -rf "$SP/Autoupdate" "$SP/Updater.app" "$SP/XPCServices/Installer.xpc"
defaults write "$BUNDLE_ID" SUEnableAutomaticChecks -bool false
defaults write "$BUNDLE_ID" SUAutomaticallyUpdate -bool false
rm -f "$C/embedded.provisionprofile"

echo "Signing locally (ad-hoc)…"
# Re-sign inside-out. Entitlements that only OpenAI's Apple team may use are dropped,
# because macOS refuses to launch locally signed code that claims them.
sign() {
  local target="$1" ent="$WORK/ent.plist"
  if codesign -d --entitlements "$ent" --xml "$target" 2>/dev/null && [ -s "$ent" ]; then
    python3 - "$ent" <<'PY'
import plistlib, sys
p = sys.argv[1]
d = plistlib.load(open(p, 'rb'))
for k in list(d):
    if k in ('com.apple.application-identifier', 'keychain-access-groups',
             'com.apple.security.application-groups') or k.startswith('com.apple.developer.'):
        del d[k]
plistlib.dump(d, open(p, 'wb'))
PY
    codesign --force --sign - --entitlements "$ent" "$target" 2>&1 | grep -v "replacing existing signature" || true
  else
    codesign --force --sign - "$target" 2>&1 | grep -v "replacing existing signature" || true
  fi
  rm -f "$ent"
}
FW="$C/Frameworks/Codex Framework.framework/Versions/Current"
for f in "$FW/Libraries/"*.dylib; do sign "$f"; done
for f in "$FW/Helpers/"*; do sign "$f"; done
sign "$C/Frameworks/Codex Framework.framework"
[ -d "$SP/XPCServices/Downloader.xpc" ] && sign "$SP/XPCServices/Downloader.xpc"
sign "$C/Frameworks/Sparkle.framework"
for f in "$C/PlugIns/"*; do [ -e "$f" ] && sign "$f"; done
sign "$C/MacOS/ChatGPT"
sign "$APP"

codesign --verify --strict "$APP" && echo "Signature OK"
defaults read "$SRC/Contents/Info" CFBundleVersion > "$C/Resources/.doppel-source-version"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
rm -rf "$WORK"
echo "Installed $APP (ChatGPT build $(cat "$C/Resources/.doppel-source-version"))"
