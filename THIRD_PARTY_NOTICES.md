# Third-party notices

Voicey itself is released under the [MIT License](LICENSE). It includes, downloads or runs the following
third-party software, each under its own license.

## Bundled inside the app

These are copied into `Voicey.app/Contents/Resources/whisper/` together with their license texts, which are also kept in
[`Resources/licenses/`](Resources/licenses).

| Component | What it is | License | License text |
|---|---|---|---|
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | the speech-to-text engine | MIT, © The ggml authors | [LICENSE-whisper.cpp](Resources/licenses/LICENSE-whisper.cpp) |
| [ggml](https://github.com/ggml-org/ggml) | the tensor library whisper.cpp runs on, including its Apple GPU (Metal) and CPU backends | MIT, © The ggml authors | [LICENSE-ggml](Resources/licenses/LICENSE-ggml) |
| [LLVM OpenMP runtime (libomp)](https://openmp.llvm.org) | multi-threading support used by ggml | Apache License 2.0 with LLVM Exceptions | [LICENSE-libomp](Resources/licenses/LICENSE-libomp) |

## Downloaded when you use it (not part of Voicey)

| Component | What it is | License |
|---|---|---|
| Whisper speech models | ggml conversions of OpenAI's [Whisper](https://github.com/openai/whisper) models, fetched from [huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp) the first time you pick one | MIT, © OpenAI |

## Run on your Mac if you have them (not included or redistributed)

Voicey can send transcript text to Claude Code or Codex if you have installed and signed in to them. They are separate
products with their own licenses and terms, which apply to your use of them.

## Apple frameworks

Voicey uses frameworks that ship with macOS (AppKit, SwiftUI, Speech, AVFoundation and others) under Apple's terms.
