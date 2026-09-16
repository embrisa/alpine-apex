#!/bin/sh
# Build the native skier math kernel for macOS arm64 with the pinned godot-cpp.
# Mirrors scripts/build_skier.ps1; the dylib belongs in addons/alpine_skier/bin.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOLS="$ROOT/.tools/skier-mac"
DEP="$TOOLS/godot-cpp"
PIN=e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77 # Official godot-4.5-stable, compatible with 4.7.2.
BUILD="$TOOLS/build"
mkdir -p "$TOOLS"
if [ ! -d "$DEP" ]; then
    git clone --depth 1 --branch godot-4.5-stable https://github.com/godotengine/godot-cpp.git "$DEP"
fi
ACTUAL=$(git -C "$DEP" rev-parse HEAD)
if [ "$ACTUAL" != "$PIN" ]; then
    echo "godot-cpp must be pinned to $PIN (found $ACTUAL). Existing dependency directory was not modified." >&2
    exit 1
fi
cmake -S "$ROOT/native/skier" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release "-DGODOT_CPP_PATH=$DEP"
cmake --build "$BUILD" --config Release --parallel 6 --target alpine_skier
OUT="$ROOT/addons/alpine_skier/bin"
mkdir -p "$OUT"
cp "$BUILD/alpine_skier.macos.arm64.dylib" "$OUT/"
ls -l "$OUT/alpine_skier.macos.arm64.dylib"
