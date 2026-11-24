# Voicey

**Dictate into any Mac app.** Press a shortcut, talk, and Voicey types the polished text where your cursor is.

![Latest release](https://img.shields.io/github/v/release/anantamishra/voicey?label=release)
![MIT license](https://img.shields.io/badge/license-MIT-green)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Apple silicon](https://img.shields.io/badge/Apple%20silicon-required-lightgrey)

## Features

- **Speech to text on your Mac.** A built-in Whisper engine (or Apple's recognizer) runs locally. Your audio is never uploaded.
- **AI polish.** An AI tool you already have, Claude Code or Codex, fixes punctuation, filler words and misheard names. Only the transcript text is sent to it.
- **One key, three gestures.** Hold to talk, press once to start and stop, or double-tap for hands-free. Any key works, including a single modifier such as `fn` or Right ⌥.
- **Made for you.** A personal dictionary, a different tone per app (formal in Mail, casual in Slack) and snippets that expand a short phrase into saved text.
- **Live pop-up** that shows your words as you speak.
- **A regular Mac app with a menu-bar icon.** It has a Dock icon (optional) and keeps listening for your shortcut after you close its windows.
- **First-run setup** that checks permissions, finds your AI tools (and can install them) and downloads the speech model.
- **Updates from inside the app.**

## Install

Voicey needs **macOS 13 or later on an Apple silicon Mac.**

### Quick install (recommended)

Paste this in Terminal. It downloads the latest release, checks its checksum, installs it into Applications and opens it,
with no "could not verify" warning:

```bash
curl -fsSL https://raw.githubusercontent.com/anantamishra/voicey/main/install.sh | bash
```

Prefer to read the script first?

```bash
curl -fsSLO https://raw.githubusercontent.com/anantamishra/voicey/main/install.sh
less install.sh      # read it
bash install.sh
```

### Manual install

1. Download [`Voicey.zip`](https://github.com/anantamishra/voicey/releases/latest/download/Voicey.zip) (always the latest
   version, or pick one from the [releases page](https://github.com/anantamishra/voicey/releases)) and unzip it.
2. Drag **Voicey.app** into your **Applications** folder.
3. Open it. macOS will say it *"could not verify Voicey is free of malware"*, because the app is not notarized by Apple yet.
   Click **Done**, then open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   Or run this once in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Voicey.app
   ```

### First launch

A setup screen walks you through four things:

1. **Permissions.** Microphone (to hear you), Speech Recognition (for the live preview) and Accessibility (to paste at your cursor).
   Without Accessibility, Voicey can only copy the text and you have to paste it yourself.
2. **An AI tool.** Voicey detects Claude Code and Codex, can install either with one click, and has a **Test** button.
3. **Transcription.** The Whisper engine is built in. A speech model downloads automatically, or you can choose Apple's recognizer instead.
4. **A summary** of what you picked.

You can run the setup again any time from **Settings → General → Run setup again**.

## Using Voicey

The default shortcut is **⌃⌥ Space**. You can record any other key in **Settings → Dictation**.

| You do | What happens |
|---|---|
| **Hold** the shortcut | Records while you hold it. It stops when you let go. |
| **Press once** | Starts recording. Press again to stop. |
| **Double-tap** | Hands-free recording that continues until you press once more. |

When you stop, Voicey transcribes, polishes the text and pastes it into the app you were using.
A floating pop-up shows your words, then "Transcribing…" and "Polishing…" while it works.

### The menu-bar menu

Start or stop dictation, open **Settings**, **Check for Updates**, and **Copy Last Transcription** (⇧⌘C) if you want the
last text again.

### Settings

| Page | What you can change |
|---|---|
| **Dictation** | Shortcut (any key, including a single modifier), mode, language, live pop-up, paste at cursor |
| **Recognition** | Whisper or Apple's recognizer, which Whisper model, silence trimming |
| **AI polish** | Which tool and model, a connection test, extra instructions such as "formal tone" |
| **Dictionary** | Names and terms to spell correctly, shared with Whisper, Apple's recognizer and the AI tool |
| **App tones** | A writing style per app, for example formal in Mail and casual in Slack |
| **Snippets** | Say "my address" and the saved text is pasted exactly as written |
| **General** | Open at login, Dock icon, updates, run setup again |

## How it works

1. Your voice is recorded and, with the pop-up on, previewed live by Apple's recognizer.
2. Silence is trimmed, and **Whisper** (running on your Mac) produces the final text.
3. Snippet phrases are set aside so the AI can't reword them.
4. The AI tool you chose cleans up the text, using your dictionary and the tone for the app you're in.
5. The snippets go back in, and the text is pasted at your cursor.

**Privacy:** audio never leaves your Mac. The only thing sent anywhere is the transcript text, and only to the AI tool
you picked, using your own login with it. Turn **Polish with AI** off and nothing is sent at all.

## Troubleshooting

| Problem | Fix |
|---|---|
| The text is copied but not pasted | Turn Voicey on under **System Settings → Privacy & Security → Accessibility**, then quit and reopen Voicey. |
| The shortcut does nothing | Another app may use it. Record a different one in **Settings → Dictation**. If you use a single modifier like `fn`, check Accessibility too. |
| `fn` opens the emoji picker | Set **System Settings → Keyboard → "Press 🌐 key to"** to *Do Nothing*. |
| "Apple could not verify Voicey…" | See **Manual install** above, or use the quick install line. |
| Whisper doesn't run | On an older macOS the built-in engine may not start, so Voicey uses Apple's recognizer instead. |
| An AI tool test fails with a sign-in message | Click **Sign in** next to the tool and finish in your browser. |

The activity log is at `~/Library/Logs/Voicey.log`, and downloaded speech models are in
`~/Library/Application Support/Voicey/models`.

## Build from source

You need Xcode or the Command Line Tools.

```bash
./build.sh                 # compiles, bundles the Whisper engine, signs
open build/Voicey.app
swift test                 # runs the test suite
```

`build.sh` copies a Whisper engine from Homebrew into the app (`brew install whisper-cpp`).
`tools/build_whisper.sh` builds a portable copy instead. With neither, Voicey falls back to Apple's recognizer.

### Releasing

Releases, signing and notarization are covered in [RELEASING.md](RELEASING.md). The version lives in `VERSION`, and
release notes in `CHANGELOG.md`.

### Project layout

| Path | What is in it |
|---|---|
| `Sources/Voicey` | the app |
| `Tests/VoiceyTests` | unit tests for gestures, updates, dictionary, snippets, shortcuts and more |
| `tools/` | icon generation, Whisper bundling, release script |
| `install.sh` | the Terminal installer |
| `LICENSE`, `THIRD_PARTY_NOTICES.md`, `Resources/licenses/` | Voicey's license and the licenses of what it bundles |
| `RELEASING.md` | how to cut and publish a release |

## Status and license

An early, personal project, released under the [MIT License](LICENSE).

Voicey bundles [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and ggml (MIT) and the LLVM OpenMP runtime
(Apache 2.0 with LLVM Exceptions). Their notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and the
license texts travel inside the app.
