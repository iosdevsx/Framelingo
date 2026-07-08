#!/bin/sh
# Rebuilds the prebuilt whisper artifacts in BundledTools/Whisper from
# whisper.cpp source. Only needed when upgrading whisper.cpp -- the app
# itself never compiles whisper, it shells out to the bundled whisper-cli
# (see LocalWhisperSpeechToTextProvider).
#
# The currently bundled artifacts were built from whisper.cpp v1.8.4
# (libwhisper 1.8.4, libggml 0.9.8), arm64, Metal + BLAS enabled.
#
# whisper-cli finds its dylibs via LC_RPATH = @executable_path, so all
# artifacts must stay flat in one directory; install_name_tool below
# rewrites the rpath accordingly.
#
# Usage: Scripts/build-whisper.sh [tag]   (default: v1.8.4)

set -eu

TAG="${1:-v1.8.4}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/whisper.cpp"
OUT_DIR="$ROOT_DIR/BundledTools/Whisper"

if [ ! -d "$SRC_DIR" ]; then
    echo "==> Cloning whisper.cpp $TAG (source tree is not kept in this repo)"
    git clone --depth 1 --branch "$TAG" \
        https://github.com/ggml-org/whisper.cpp.git "$SRC_DIR"
fi

echo "==> Building whisper.cpp (Release, shared libs, Metal + BLAS)"
cmake -S "$SRC_DIR" -B "$SRC_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DGGML_METAL=ON \
    -DGGML_BLAS=ON \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON
cmake --build "$SRC_DIR/build" -j --target whisper-cli

echo "==> Collecting artifacts into $OUT_DIR"
mkdir -p "$OUT_DIR"
cp "$SRC_DIR/build/bin/whisper-cli" "$OUT_DIR/"
# cp -L: the build dir has version symlinks (libwhisper.dylib ->
# libwhisper.1.dylib); the bundle needs the real files whisper-cli links
# against (@rpath/libwhisper.1.dylib etc).
find "$SRC_DIR/build" -name "libwhisper.1.dylib" -exec cp -L {} "$OUT_DIR/" \;
find "$SRC_DIR/build" -name "libggml*.0.dylib" -exec cp -L {} "$OUT_DIR/" \;

echo "==> Pointing whisper-cli rpath at @executable_path"
for rpath in $(otool -l "$OUT_DIR/whisper-cli" | awk '/LC_RPATH/{getline; getline; print $2}'); do
    install_name_tool -delete_rpath "$rpath" "$OUT_DIR/whisper-cli" 2>/dev/null || true
done
install_name_tool -add_rpath "@executable_path" "$OUT_DIR/whisper-cli"

echo "==> Smoke test"
"$OUT_DIR/whisper-cli" --help >/dev/null

echo ""
echo "Done. Artifacts in $OUT_DIR -- commit them."
echo "Codesigning is handled later by Scripts/sign-bundled-tools.sh during archive."
