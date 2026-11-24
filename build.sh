#!/bin/zsh
set -e
cd "$(dirname "$0")"
[ -f tools/release.conf ] && source tools/release.conf       # SIGN_IDENTITY, FEED_URL, ...

# Signing: a Developer ID identity when SIGN_IDENTITY is set (needed to notarize), otherwise ad-hoc.
if [ -n "${SIGN_IDENTITY:-}" ]; then
  security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY" \
    || { echo "Signing identity not found in your keychain: $SIGN_IDENTITY"; exit 1; }
fi
export SIGN_IDENTITY

swift build -c release
APP=build/Voicey.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Voicey "$APP/Contents/MacOS/Voicey"
mkdir -p "$APP/Contents/Resources"
./tools/bundle_whisper.sh "$APP"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"

# Version comes from the VERSION file; the build number is a timestamp unless the release script sets one.
VERSION=$(tr -d ' \n' < VERSION)
BUILD=${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}
PB=/usr/libexec/PlistBuddy
$PB -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
[ -n "${FEED_URL:-}" ] && $PB -c "Add :VoiceyFeedURL string $FEED_URL" "$APP/Contents/Info.plist"
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --entitlements Resources/Voicey.entitlements --sign "$SIGN_IDENTITY" "$APP"
  SIGNED="Developer ID"
else
  codesign --force --sign - -r="designated => identifier \"local.voicey.app\"" "$APP"
  SIGNED="ad-hoc"
fi
codesign --verify --deep --strict "$APP"
echo "Built $APP  v$VERSION ($BUILD), signed $SIGNED  ->  open $APP"
