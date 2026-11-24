#!/bin/zsh
# Builds a self-contained whisper-cli (static, Metal GPU code embedded, macOS 13+, Apple silicon)
# into build/whisper/whisper-cli so Voicey can ship its own copy and users never need Homebrew.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
WHISPER_TAG="v1.9.5"
CMAKE_VERSION="3.31.6"
OUT="$ROOT/build/whisper"
WORK="$ROOT/build/whisper-work"
mkdir -p "$OUT" "$WORK"

if [ -x "$OUT/whisper-cli" ] && [ -f "$OUT/VERSION" ] && [ "$(cat "$OUT/VERSION")" = "$WHISPER_TAG" ]; then
  echo "whisper-cli $WHISPER_TAG already built"; exit 0
fi

# cmake: use the system one if present, otherwise a checksummed download kept inside build/
if command -v cmake >/dev/null 2>&1; then
  CMAKE=$(command -v cmake)
else
  CM_DIR="$WORK/cmake-$CMAKE_VERSION-macos-universal"
  if [ ! -x "$CM_DIR/CMake.app/Contents/bin/cmake" ]; then
    BASE="https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION"
    curl -fsSL "$BASE/cmake-$CMAKE_VERSION-macos-universal.tar.gz" -o "$WORK/cmake.tar.gz"
    curl -fsSL "$BASE/cmake-$CMAKE_VERSION-SHA-256.txt" -o "$WORK/cmake-sha.txt"
    EXPECTED=$(grep "cmake-$CMAKE_VERSION-macos-universal.tar.gz" "$WORK/cmake-sha.txt" | awk '{print $1}')
    ACTUAL=$(shasum -a 256 "$WORK/cmake.tar.gz" | awk '{print $1}')
    [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || { echo "cmake checksum mismatch"; exit 1; }
    tar -xzf "$WORK/cmake.tar.gz" -C "$WORK"
  fi
  CMAKE="$CM_DIR/CMake.app/Contents/bin/cmake"
fi
echo "cmake: $CMAKE"

SRC="$WORK/whisper.cpp"
if [ ! -d "$SRC/.git" ]; then
  git clone --quiet --depth 1 --branch "$WHISPER_TAG" https://github.com/ggml-org/whisper.cpp "$SRC"
fi

"$CMAKE" -S "$SRC" -B "$WORK/build" -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_OPENMP=OFF -DGGML_NATIVE=OFF \
  -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF
"$CMAKE" --build "$WORK/build" --config Release --target whisper-cli -j "$(sysctl -n hw.ncpu)"

BIN=$(find "$WORK/build" -type f -name whisper-cli -perm -u+x | head -1)
[ -n "$BIN" ] || { echo "whisper-cli was not produced"; exit 1; }
cp "$BIN" "$OUT/whisper-cli"
strip -x "$OUT/whisper-cli"
codesign --force --sign - "$OUT/whisper-cli"
cp "$SRC/LICENSE" "$OUT/LICENSE"
echo "$WHISPER_TAG" > "$OUT/VERSION"
echo "built $OUT/whisper-cli"
otool -L "$OUT/whisper-cli" | tail -n +2
