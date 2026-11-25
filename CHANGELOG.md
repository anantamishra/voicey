# Changelog

Each release needs a `## X.Y.Z` section here. `tools/release.sh` uses it as the release notes
shown to people in the update prompt.

## 1.2.0 - 2026-11-24

- Learn from my dictation (off by default, in Settings → General): Voicey suggests dictionary words, both names you say often and words you correct after it pastes, and a tone for each app. You approve every suggestion, and it keeps only candidate words and counts, never what you said.
- Faster: the AI call no longer loads your other Claude tools (about 2 s instead of 5 s), and short, clean sentences skip the AI entirely.
- Extra instructions now work reliably, including sign-offs, translation and lists, and a recording of only "um" no longer produces text.
- The activity log no longer contains what you said, stays under about 200 KB, and can be cleared in Settings → General. The old log is wiped once on first launch.

## 1.1.0 - 2026-11-24

- Voicey now stops and transcribes by itself after a pause in your speech. Choose 2, 3 (default) or 5 seconds, or never, in Settings → Dictation.
- Double clap to start: clap twice and Voicey starts a hands-free dictation. It is off by default because it keeps the microphone open to listen for claps (nothing is recorded or saved).
- The website lists both.

## 1.0.1 - 2026-11-24

- Voicey is now released under the MIT License. The licenses of the bundled speech engine (whisper.cpp, ggml, libomp) travel inside the app, and the About window shows the copyright.
- Updates are only accepted from the same Apple developer as the running copy, once releases are signed with a Developer ID.
- Release builds can be signed and notarized, which will remove the "could not verify" warning on first launch.
- A Terminal installer that opens without that warning: see the README.

## 1.0.0 - 2026-11-24

- Dictate into any app: a global shortcut records, transcribes and pastes at the cursor.
- Shortcut gestures: hold to talk, press to start/stop, double-tap for hands-free. Any key, including a single modifier key.
- Whisper speech engine built into the app, with silence trimming. Apple's recognizer as an alternative.
- AI polish through Claude Code or Codex, with one-click install and a connection test.
- Personal dictionary, per-app tone and snippets.
- Floating live-text pop-up, copy-last-transcription menu item, sidebar settings and a first-run setup.
- A regular Mac app (Dock icon, app switcher, standard menus) that also keeps a menu-bar icon. "Show in Dock" can be switched off.
- In-app updates, a permanent test suite and a release script.
