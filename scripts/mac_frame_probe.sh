#!/bin/sh
# Focused-window macOS frame probe. Usage:
#   scripts/mac_frame_probe.sh LABEL [probe or game arguments...]
# Launches tests/mac_frame_probe.gd through LaunchServices so the window is
# focused (a shell-exec'd window blocks in CAMetalLayer nextDrawable), with the
# full-mountain policy flags set. Results: artifacts/mac_probe/LABEL.json.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LABEL=${1:?label required}; shift
ENGINE=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
BUNDLE=${ENGINE%/Contents/MacOS/*}
export ALPINE_FULL_MOUNTAIN=1
export ALPINE_FULL_MOUNTAIN_REASON=${ALPINE_FULL_MOUNTAIN_REASON:-"macOS frame probe $LABEL on the Standard mountain"}
rm -f "$ROOT/artifacts/mac_probe/$LABEL.json"
open -n -W -a "$BUNDLE" --args --path "$ROOT" --script tests/mac_frame_probe.gd -- "--probe-label=$LABEL" "$@"
test -f "$ROOT/artifacts/mac_probe/$LABEL.json" && echo "$ROOT/artifacts/mac_probe/$LABEL.json"
