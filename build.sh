#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/Voicey.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Voicey "$APP/Contents/MacOS/Voicey"
mkdir -p "$APP/Contents/Resources"
./tools/bundle_whisper.sh "$APP"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"

# Version comes from the VERSION file; the build number is a timestamp unless the release script sets one.
VERSION=$(tr -d ' \n' < VERSION)
BUILD=${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}
[ -f tools/release.conf ] && source tools/release.conf
PB=/usr/libexec/PlistBuddy
$PB -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
[ -n "${FEED_URL:-}" ] && $PB -c "Add :VoiceyFeedURL string $FEED_URL" "$APP/Contents/Info.plist"
codesign --force --sign - -r="designated => identifier \"local.voicey.app\"" "$APP"
echo "Built $APP  v$VERSION ($BUILD)  ->  open $APP"
