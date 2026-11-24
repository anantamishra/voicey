# Voicey

Dictate into any Mac app. Press a shortcut, talk, and Voicey types the polished text where your cursor is.

- **Speech to text on your Mac.** The Whisper engine (or Apple's recognizer) runs locally. Audio is never uploaded.
- **AI polish.** An AI tool you already have installed, Claude Code or Codex, fixes punctuation, filler words and misheard names. Only the transcript text is sent to it.
- **One key, three gestures.** Hold to talk, press once to start and stop, or double-tap for hands-free. Any key works, including a single modifier such as `fn` or Right ⌥.
- **Made for you.** A personal dictionary, a different tone per app (formal in Mail, casual in Slack) and snippets that expand a short phrase into saved text.
- **A regular Mac app with a menu-bar icon.** It has a Dock icon (switch it off in Settings → General for menu-bar only) and keeps listening for your shortcut after you close its windows.
- **Live pop-up** that shows your words as you speak, and a menu-bar item to copy the last transcription.
- **First-run setup** that checks permissions, finds your AI tools (and can install them) and fetches the speech model.
- **Updates from inside the app.** See [RELEASING.md](RELEASING.md).

## Requirements

macOS 13 or later on Apple silicon, with Xcode or the Command Line Tools to build it.

## Build and run

    ./build.sh
    open build/Voicey.app

`build.sh` compiles the app, bundles a Whisper engine into it and signs it. The engine is copied from Homebrew
(`brew install whisper-cpp`); `tools/build_whisper.sh` compiles a portable copy instead. Without either, Voicey
falls back to Apple's recognizer.

The first launch opens a setup screen that asks for Microphone, Speech Recognition and Accessibility access.
Accessibility is what lets Voicey paste at your cursor.

## Tests

    swift test

## Layout

| Path | What is in it |
|---|---|
| `Sources/Voicey` | the app |
| `Tests/VoiceyTests` | unit tests for gestures, updates, dictionary, snippets, shortcuts and more |
| `tools/` | icon generation, Whisper bundling, release script |
| `RELEASING.md` | how to cut and publish a release |

## Status and license

Early, personal project. No license has been chosen yet, so all rights are reserved for now.
Releases bundle [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT).
