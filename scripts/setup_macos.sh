#!/bin/sh
# Rebuild a macOS Godot import cache without replacing user-edited .import files.
set -eu

usage() {
    cat <<'EOF'
Usage: ./scripts/setup_macos.sh --rebuild-cache [--cache-backup /absolute/new/path]

On a checkout with an existing .godot directory, --cache-backup is required.
The old cache is moved there unchanged before re-importing. The directory must
not already exist. Tracked .import sidecars that were clean beforehand are
restored after Godot has rebuilt the local macOS cache; pre-existing unstaged
sidecar edits are preserved.
EOF
}

ALPINE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALPINE_BACKUP=""
ALPINE_REBUILD=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --rebuild-cache) ALPINE_REBUILD=1 ;;
        --cache-backup)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            ALPINE_BACKUP=$2
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
    shift
done

[ "$ALPINE_REBUILD" -eq 1 ] || { usage >&2; exit 2; }
[ "$(uname -s)" = Darwin ] || { echo "This recovery helper is for macOS." >&2; exit 2; }
git -C "$ALPINE_ROOT" rev-parse --is-inside-work-tree >/dev/null
if ! git -C "$ALPINE_ROOT" diff --cached --quiet -- '*.import'; then
    echo "Refusing to rebuild while tracked .import sidecars are staged." >&2
    exit 2
fi

if [ -d "$ALPINE_ROOT/.godot" ]; then
    [ -n "$ALPINE_BACKUP" ] || { echo "--cache-backup is required when .godot exists." >&2; exit 2; }
    case "$ALPINE_BACKUP" in
        /*) ;;
        *) echo "--cache-backup must be an absolute, new path." >&2; exit 2 ;;
    esac
    [ ! -e "$ALPINE_BACKUP" ] || { echo "Backup path already exists: $ALPINE_BACKUP" >&2; exit 2; }
    [ -d "$(dirname -- "$ALPINE_BACKUP")" ] || { echo "Backup parent does not exist." >&2; exit 2; }
    mv "$ALPINE_ROOT/.godot" "$ALPINE_BACKUP"
    echo "Previous cache moved to $ALPINE_BACKUP"
fi

ALPINE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/alpine-apex-macos-import.XXXXXX")
cleanup() {
    if [ -f "$ALPINE_TMP/dirty-imports" ]; then
        while IFS= read -r ALPINE_PATH; do
            mkdir -p "$ALPINE_ROOT/$(dirname -- "$ALPINE_PATH")"
            cp "$ALPINE_TMP/dirty/$ALPINE_PATH" "$ALPINE_ROOT/$ALPINE_PATH"
        done < "$ALPINE_TMP/dirty-imports"
    fi
    rm -rf "$ALPINE_TMP"
}
trap cleanup EXIT HUP INT TERM

git -C "$ALPINE_ROOT" diff --name-only -- '*.import' > "$ALPINE_TMP/dirty-imports"
while IFS= read -r ALPINE_PATH; do
    [ -n "$ALPINE_PATH" ] || continue
    mkdir -p "$ALPINE_TMP/dirty/$(dirname -- "$ALPINE_PATH")"
    cp "$ALPINE_ROOT/$ALPINE_PATH" "$ALPINE_TMP/dirty/$ALPINE_PATH"
done < "$ALPINE_TMP/dirty-imports"

# Godot otherwise accepts a copied/imported cache without rebuilding resources
# for this host. Touch sources, never contents, so the new local cache is complete.
git -C "$ALPINE_ROOT" ls-files -- '*.import' | while IFS= read -r ALPINE_PATH; do
    ALPINE_SOURCE=${ALPINE_PATH%.import}
    [ -f "$ALPINE_ROOT/$ALPINE_SOURCE" ] && touch "$ALPINE_ROOT/$ALPINE_SOURCE"
done

"$ALPINE_ROOT/godotw" --editor --import

# Import metadata is versioned for the Windows production workflow. Restore only
# sidecars that were clean when this recovery began; dirty sidecars restore in trap.
git -C "$ALPINE_ROOT" ls-files -- '*.import' | while IFS= read -r ALPINE_PATH; do
    if ! grep -Fqx "$ALPINE_PATH" "$ALPINE_TMP/dirty-imports"; then
        git -C "$ALPINE_ROOT" show "HEAD:$ALPINE_PATH" > "$ALPINE_ROOT/$ALPINE_PATH"
    fi
done

echo "macOS Godot cache is ready. Launch with ./godotw"
