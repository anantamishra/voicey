#!/bin/bash
# Installs the latest Voicey release into /Applications.
#   bash install.sh
# It downloads the release zip from this repository's GitHub Releases, checks its SHA-256 against the
# release's update.json, verifies the app's signature and copies it into place. Apps fetched this way
# don't carry macOS's "downloaded from the internet" flag, so there is no "could not verify" warning.
# Set INSTALL_DIR to install somewhere other than /Applications, and NO_OPEN=1 to skip opening it.
set -euo pipefail

REPO="anantamishra/voicey"
FEED="https://github.com/$REPO/releases/latest/download/update.json"
DEST_DIR="${INSTALL_DIR:-/Applications}"

fail() { echo "Error: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Voicey is a Mac app."
[ "$(uname -m)" = "arm64" ] || fail "Voicey needs an Apple silicon Mac."
[ -d "$DEST_DIR" ] && [ -w "$DEST_DIR" ] || fail "$DEST_DIR isn't writable. Use an administrator account, or set INSTALL_DIR to a folder you own."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Looking up the latest version..."
curl -fsSL "$FEED" -o "$tmp/update.json" || fail "couldn't download the release information."
version=$(plutil -extract version raw -o - "$tmp/update.json")
url=$(plutil -extract url raw -o - "$tmp/update.json")
sha=$(plutil -extract sha256 raw -o - "$tmp/update.json")
case "$url" in "https://github.com/$REPO/"*) ;; *) fail "the release points somewhere unexpected ($url).";; esac

echo "Downloading Voicey $version..."
curl -fsSL "$url" -o "$tmp/Voicey.zip" || fail "the download failed."
[ "$(shasum -a 256 "$tmp/Voicey.zip" | awk '{print $1}')" = "$sha" ] || fail "the download doesn't match its checksum, so it was not installed."

ditto -xk "$tmp/Voicey.zip" "$tmp/unpacked"
app="$tmp/unpacked/Voicey.app"
[ -d "$app" ] || fail "the download didn't contain Voicey.app."
codesign --verify --deep --strict "$app" || fail "the app's signature is damaged, so it was not installed."

# Quit a running copy first, then replace it.
osascript -e 'tell application "Voicey" to quit' >/dev/null 2>&1 || true
sleep 1
rm -rf "$DEST_DIR/Voicey.app"
ditto "$app" "$DEST_DIR/Voicey.app"
xattr -dr com.apple.quarantine "$DEST_DIR/Voicey.app" 2>/dev/null || true

echo "Installed Voicey $version in $DEST_DIR."
[ -n "${NO_OPEN:-}" ] || open "$DEST_DIR/Voicey.app"
