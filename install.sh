#!/usr/bin/env bash
# Symlink ./spent to ~/.local/bin/spent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/spent"
TARGET_DIR="$HOME/.local/bin"
TARGET="$TARGET_DIR/spent"

if [[ ! -f "$SOURCE" ]]; then
    echo "install.sh: $SOURCE not found" >&2
    exit 1
fi

chmod +x "$SOURCE"
mkdir -p "$TARGET_DIR"

if [[ -L "$TARGET" || -e "$TARGET" ]]; then
    rm -f "$TARGET"
fi

ln -s "$SOURCE" "$TARGET"
echo "linked $SOURCE -> $TARGET"

case ":$PATH:" in
    *":$TARGET_DIR:"*) ;;
    *)
        echo
        echo "$TARGET_DIR is not on your PATH. Add to ~/.zshrc:"
        echo
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac
