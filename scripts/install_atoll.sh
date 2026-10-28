#!/bin/bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  scripts/install_atoll.sh /path/to/Atoll.dmg
  scripts/install_atoll.sh /path/to/Atoll.app

Options:
  --keep-dmg       Keep the source DMG instead of deleting it after installation.
  --clean-build    Remove this repository's build/DerivedData after installation.
EOF
}

KEEP_DMG=false
CLEAN_BUILD=false
SOURCE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-dmg)
            KEEP_DMG=true
            shift
            ;;
        --clean-build)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$SOURCE" ]]; then
                echo "Only one DMG or app path may be supplied." >&2
                usage >&2
                exit 2
            fi
            SOURCE="$1"
            shift
            ;;
    esac
done

if [[ -z "$SOURCE" ]]; then
    usage >&2
    exit 2
fi

SOURCE="$(cd "$(dirname "$SOURCE")" && pwd)/$(basename "$SOURCE")"
if [[ ! -e "$SOURCE" ]]; then
    echo "Source does not exist: $SOURCE" >&2
    exit 1
fi

APP_PATH=""
MOUNT_POINT=""

cleanup() {
    if [[ -n "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" -quiet || true
        rmdir "$MOUNT_POINT" 2>/dev/null || true
    fi
}
trap cleanup EXIT

case "$SOURCE" in
    *.dmg|*.DMG)
        MOUNT_POINT="$(mktemp -d "${TMPDIR:-/tmp}/atoll-dmg.XXXXXX")"
        hdiutil attach "$SOURCE" -readonly -nobrowse -mountpoint "$MOUNT_POINT" >/dev/null
        APP_PATH="$MOUNT_POINT/Atoll.app"
        ;;
    *.app)
        APP_PATH="$SOURCE"
        ;;
    *)
        echo "Expected an Atoll .dmg or .app file: $SOURCE" >&2
        exit 2
        ;;
esac

if [[ ! -d "$APP_PATH" ]]; then
    echo "Atoll.app was not found in: $SOURCE" >&2
    exit 1
fi

echo "Installing Atoll to /Applications/Atoll.app..."
osascript -e 'tell application "Atoll" to quit' >/dev/null 2>&1 || true
sudo rm -rf "/Applications/Atoll.app"
sudo ditto "$APP_PATH" "/Applications/Atoll.app"

if [[ ! -d "/Applications/Atoll.app" ]]; then
    echo "Installation failed: /Applications/Atoll.app was not created." >&2
    exit 1
fi

sudo xattr -dr com.apple.quarantine "/Applications/Atoll.app" 2>/dev/null || true

if [[ "$SOURCE" == *.dmg || "$SOURCE" == *.DMG ]] && [[ "$KEEP_DMG" == false ]]; then
    rm -f "$SOURCE"
    echo "Deleted source DMG: $SOURCE"
fi

if [[ "$CLEAN_BUILD" == true ]]; then
    REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    if [[ -d "$REPOSITORY_ROOT/build/DerivedData" ]]; then
        rm -rf "$REPOSITORY_ROOT/build/DerivedData"
        echo "Deleted build/DerivedData."
    fi
fi

echo "Installed: /Applications/Atoll.app"
open -a Atoll
