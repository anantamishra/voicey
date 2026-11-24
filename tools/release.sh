#!/bin/zsh
# Cut a release:  tools/release.sh [patch|minor|major|X.Y.Z]
#   1. checks CHANGELOG.md has notes for the new version
#   2. bumps VERSION and builds the app with it
#   3. writes dist/Voicey-X.Y.Z.zip and dist/update.json (the feed the app checks)
# Upload both files to wherever DOWNLOAD_BASE / FEED_URL in tools/release.conf point.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f tools/release.conf ] && source tools/release.conf

CUR=$(tr -d ' \n' < VERSION)
ARG=${1:-patch}
IFS=. read -r MA MI PA <<< "$CUR"
case "$ARG" in
  patch) NEW="$MA.$MI.$((PA+1))" ;;
  minor) NEW="$MA.$((MI+1)).0" ;;
  major) NEW="$((MA+1)).0.0" ;;
  [0-9]*.[0-9]*.[0-9]*) NEW="$ARG" ;;
  *) echo "usage: $0 [patch|minor|major|X.Y.Z]"; exit 2 ;;
esac

# the new version must not go backwards
if [ "$(printf '%s\n%s\n' "$CUR" "$NEW" | sort -V | head -1)" != "$CUR" ]; then echo "$NEW is older than the current $CUR"; exit 1; fi

# release notes
if ! grep -q -E "^## $NEW( |$)" CHANGELOG.md; then
  echo "CHANGELOG.md has no '## $NEW' section. Describe what changed there first, then run this again."; exit 1
fi
NOTES=$(awk -v v="$NEW" '$0 ~ "^## "v"( |$)" {f=1; next} /^## / {f=0} f' CHANGELOG.md | sed '/^$/d')

echo "Running the tests first..."
swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1
swift test >/dev/null 2>&1 || { echo "Tests failed. Fix them before releasing (run: swift test)."; exit 1; }

echo "$NEW" > VERSION
export BUILD_NUMBER=$(date +%Y%m%d%H%M)
./build.sh

# Notarize (needs a Developer ID build): Apple scans the app, then the ticket is stapled onto it so it opens offline.
if [ -n "${NOTARY_PROFILE:-}" ]; then
  [ -n "${SIGN_IDENTITY:-}" ] || { echo "NOTARY_PROFILE is set but SIGN_IDENTITY is not. Only Developer ID builds can be notarized."; exit 1; }
  echo "Sending to Apple for notarization (usually a few minutes)..."
  ditto -c -k --keepParent build/Voicey.app build/notarize.zip
  if ! xcrun notarytool submit build/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | tee build/notarize.log | tail -4 | grep -q "status: Accepted"; then
    echo "Notarization was not accepted. Details:"; cat build/notarize.log | tail -20; exit 1
  fi
  xcrun stapler staple build/Voicey.app
  spctl --assess --type execute -vv build/Voicey.app 2>&1 | head -3
  rm -f build/notarize.zip
elif [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "Warning: signed with Developer ID but NOTARY_PROFILE is not set, so macOS will still warn on first launch."
else
  echo "Warning: not signed with a Developer ID, so macOS will warn on first launch."
fi

mkdir -p dist
ZIP="dist/Voicey-$NEW.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Voicey.app "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
BASE="${DOWNLOAD_BASE:-https://example.com/voicey}"

VERSION="$NEW" BUILD="$BUILD_NUMBER" URL="$BASE/Voicey-$NEW.zip" SHA="$SHA" NOTES="$NOTES" python3 - <<'PY'
import json, os
feed = {"version": os.environ["VERSION"], "build": os.environ["BUILD"], "url": os.environ["URL"],
        "sha256": os.environ["SHA"], "notes": os.environ["NOTES"], "minMacOS": "13.0"}
json.dump(feed, open("dist/update.json", "w"), indent=2)
PY

echo
echo "Released $NEW (build $BUILD_NUMBER)"
echo "  $ZIP   sha256 $SHA"
echo "  dist/update.json"
echo "Upload both to: $BASE/  (the app reads ${FEED_URL:-the update feed URL set in Settings})"
