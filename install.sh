#!/usr/bin/env bash
# Symlink ./spent to ~/.local/bin/spent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/spent"
TARGET_DIR="$HOME/.local/bin"
TARGET="$TARGET_DIR/spent"

MAN_SOURCE="$SCRIPT_DIR/man/spent.1"
MAN_TARGET_DIR="$HOME/.local/share/man/man1"
MAN_TARGET="$MAN_TARGET_DIR/spent.1"

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

if [[ -f "$MAN_SOURCE" ]]; then
    mkdir -p "$MAN_TARGET_DIR"
    if [[ -L "$MAN_TARGET" || -e "$MAN_TARGET" ]]; then
        rm -f "$MAN_TARGET"
    fi
    ln -s "$MAN_SOURCE" "$MAN_TARGET"
    echo "linked $MAN_SOURCE -> $MAN_TARGET"
fi

case ":$PATH:" in
    *":$TARGET_DIR:"*) ;;
    *)
        echo
        echo "$TARGET_DIR is not on your PATH. Add to ~/.zshrc:"
        echo
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

if [[ -f "$MAN_SOURCE" ]]; then
    if ! manpath 2>/dev/null | tr ':' '\n' | grep -qx "$HOME/.local/share/man"; then
        echo
        echo "$HOME/.local/share/man is not on your manpath. Either add to ~/.zshrc:"
        echo
        echo "  export MANPATH=\"\$HOME/.local/share/man:\$(manpath 2>/dev/null)\""
        echo
        echo "Or query directly: man -M \"\$HOME/.local/share/man\" spent"
    fi
fi
