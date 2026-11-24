# Changelog

Each release needs a `## X.Y.Z` section here. `tools/release.sh` uses it as the release notes
shown to people in the update prompt.

## 1.0.0 - 2026-11-24

- Dictate into any app: a global shortcut records, transcribes and pastes at the cursor.
- Shortcut gestures: hold to talk, press to start/stop, double-tap for hands-free. Any key, including a single modifier key.
- Whisper speech engine built into the app, with silence trimming. Apple's recognizer as an alternative.
- AI polish through Claude Code or Codex, with one-click install and a connection test.
- Personal dictionary, per-app tone and snippets.
- Floating live-text pop-up, copy-last-transcription menu item, sidebar settings and a first-run setup.
- A regular Mac app (Dock icon, app switcher, standard menus) that also keeps a menu-bar icon. "Show in Dock" can be switched off.
- In-app updates, a permanent test suite and a release script.
