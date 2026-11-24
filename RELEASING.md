# Releasing Voicey

The version lives in one place: the `VERSION` file. `build.sh` stamps it into the app
(`CFBundleShortVersionString`), together with a build number (a timestamp).

## One-time setup

1. Pick where releases are hosted (any static host that serves HTTPS: GitHub Releases, S3, your own site).
2. `cp tools/release.conf.example tools/release.conf` and set:
   - `DOWNLOAD_BASE` – where the zip will be uploaded (no trailing slash)
   - `FEED_URL` – where `update.json` will be uploaded. This address is baked into the app at build time.
   - GitHub Releases example: `FEED_URL=https://github.com/<you>/<repo>/releases/latest/download/update.json`
     and `DOWNLOAD_BASE=https://github.com/<you>/<repo>/releases/latest/download`.

## Signing and notarizing (removes the "Apple could not verify" warning)

You need an Apple Developer Program membership and a **Developer ID Application** certificate (not "Apple Development").

1. Create the certificate: Xcode → Settings → Accounts → your team → Manage Certificates → **+** → *Developer ID Application*.
   (Only the Account Holder or an Admin can.) Check it is in your keychain: `security find-identity -v -p codesigning`.
2. Create an app-specific password at <https://account.apple.com> → Sign-In and Security, then store a notarization login once:

       xcrun notarytool store-credentials voicey-notary --apple-id YOU@EXAMPLE.COM --team-id YOURTEAMID

   (It prompts for the app-specific password, so it never lands in a file or in your shell history.)
3. In `tools/release.conf` set `SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"` and `NOTARY_PROFILE="voicey-notary"`.

`tools/release.sh` then signs with the hardened runtime, submits the app to Apple, waits, staples the ticket and checks it
with `spctl`. Switching from the ad-hoc signature to a Developer ID one makes macOS ask for Microphone / Accessibility once
more. Updates are only accepted from the same Team ID as the running copy.

## Cutting a release

1. Add a `## X.Y.Z - date` section to `CHANGELOG.md`. Its text is what people see as “What’s new”.
2. `tools/release.sh patch` (or `minor`, `major`, or an explicit `X.Y.Z`). It runs the test suite (`swift test`) first and stops if anything fails.
3. Upload `dist/Voicey-X.Y.Z.zip` and `dist/update.json` to the places from step 1.

Running copies of Voicey notice the new `update.json` within a day (or right away via
**menu bar → Check for Updates…**), download the zip, verify its SHA-256 and code signature,
swap themselves in and relaunch.

## Testing a release before publishing

Serve `dist/` locally and point a copy of the old app at it:

    python3 -m http.server 8765 --bind 127.0.0.1 --directory dist
    /path/to/old/Voicey.app/Contents/MacOS/Voicey --update-selftest -updateFeedURL http://127.0.0.1:8765/update.json

(`http://` is accepted only for localhost; real feeds must be `https://`.)

## Good to know

- Updates keep your Microphone / Accessibility permissions because the app’s signing identity
  (`designated => identifier "local.voicey.app"`) stays the same.
- The app is ad-hoc signed. Updates installed from inside Voicey open without any warning, but a
  first install on another Mac that was downloaded in a browser will be blocked by Gatekeeper until
  the app is signed with a Developer ID and notarized.
- The bundled Whisper engine is copied from Homebrew and needs the same macOS version as the Mac it was
  built on (see `tools/build_whisper.sh` for a portable build). On a Mac where it can’t run, Voicey
  falls back to Apple’s recognizer.
