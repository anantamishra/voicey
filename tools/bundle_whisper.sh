#!/bin/zsh
# Copies a Whisper engine into the app so Voicey needs no Homebrew at run time.
#   1. build/whisper/whisper-cli  (the portable static build from tools/build_whisper.sh), if present
#   2. otherwise the Homebrew copy on this Mac, with its libraries made relocatable
# Usage: bundle_whisper.sh <App.app>
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$1"
DEST="$APP/Contents/Resources/whisper"
rm -rf "$DEST"

if [ -x build/whisper/whisper-cli ]; then
  mkdir -p "$DEST"
  cp build/whisper/whisper-cli "$DEST/whisper-cli"
  [ -f build/whisper/LICENSE ] && cp build/whisper/LICENSE "$DEST/LICENSE-whisper.cpp"
  codesign --force --sign - "$DEST/whisper-cli"
  echo "bundled portable whisper-cli"
  exit 0
fi

BIN=$(readlink -f /opt/homebrew/bin/whisper-cli 2>/dev/null || true)
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "no whisper engine to bundle (run tools/build_whisper.sh or: brew install whisper-cpp)"; exit 0
fi

mkdir -p "$DEST"
CELLAR=$(dirname "$(dirname "$BIN")")                         # .../Cellar/whisper.cpp/<v>
GGML=$(readlink -f /opt/homebrew/opt/ggml)
LIBOMP=$(readlink -f /opt/homebrew/opt/libomp)
SEARCH=("$CELLAR/lib" "$GGML/lib" "$LIBOMP/lib")

cp -L "$BIN" "$DEST/whisper-cli"
cp -L "$GGML"/libexec/*.so "$DEST/" 2>/dev/null || true       # GPU / CPU backends, loaded from next to the program
chmod u+w "$DEST"/*

find_lib() {                                                   # name -> path in the Homebrew trees
  local n="$1" d
  for d in $SEARCH; do [ -e "$d/$n" ] && { readlink -f "$d/$n"; return 0; }; done
  return 1
}

typeset -A done_files
queue=("$DEST"/*(.))
while [ ${#queue} -gt 0 ]; do
  f="${queue[1]}"; queue=("${queue[@]:1}")
  [ -n "${done_files[$f]:-}" ] && continue
  done_files[$f]=1
  case "$f" in *.so|*.dylib) install_name_tool -id "@rpath/$(basename "$f")" "$f" 2>/dev/null || true;; esac
  for dep in $(otool -L "$f" | tail -n +2 | awk '{print $1}'); do
    case "$dep" in
      /opt/homebrew/*|@rpath/*)
        name=$(basename "$dep")
        if [ ! -e "$DEST/$name" ]; then
          src=$(find_lib "$name") || { echo "cannot find $name for $f"; exit 1; }
          cp -L "$src" "$DEST/$name"; chmod u+w "$DEST/$name"
          queue+=("$DEST/$name")
        fi
        install_name_tool -change "$dep" "@rpath/$name" "$f"
        ;;
    esac
  done
  # one rpath: next to the file itself
  for rp in $(otool -l "$f" | awk '/LC_RPATH/{r=1} r&&/path /{print $2; r=0}'); do install_name_tool -delete_rpath "$rp" "$f" 2>/dev/null || true; done
  install_name_tool -add_rpath "@loader_path" "$f"
done

for f in "$DEST"/*(.); do codesign --force --sign - "$f" 2>/dev/null; done
[ -f "$CELLAR/LICENSE" ] && cp "$CELLAR/LICENSE" "$DEST/LICENSE-whisper.cpp"
[ -f "$GGML/LICENSE" ] && cp "$GGML/LICENSE" "$DEST/LICENSE-ggml"
for l in "$LIBOMP"/LICENSE*(N); do cp "$l" "$DEST/LICENSE-libomp"; done
echo "bundled Homebrew whisper-cli with $(ls "$DEST" | wc -l | tr -d ' ') files ($(du -sh "$DEST" | awk '{print $1}'))"
