#!/usr/bin/env bash
# Install (or update) the `dojo` CLI by symlinking it onto your PATH.
#
#   gh repo clone geeksilva97/dojos ~/.dojos && ~/.dojos/install.sh
#
# Re-running pulls the latest (tool + dojos) and re-links — so it doubles as the
# updater. Nothing is published anywhere; the CLI runs straight from this clone.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin/dojo.js"
BIN_DIR="${DOJO_BIN_DIR:-$HOME/.local/bin}"
LINK="$BIN_DIR/dojo"

command -v node >/dev/null 2>&1 || { echo "install: Node.js (>=18) is required but not found on PATH." >&2; exit 1; }

# If this is a git checkout, fetch the latest before linking.
# (DOJO_SKIP_PULL lets the test suite link without touching the repo's git state.)
if [ -d "$REPO_DIR/.git" ] && [ -z "${DOJO_SKIP_PULL:-}" ]; then
  echo "==> updating $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only --quiet || echo "   (pull skipped — local changes or no upstream)"
fi

chmod +x "$BIN_SRC"
mkdir -p "$BIN_DIR"
ln -sf "$BIN_SRC" "$LINK"
echo "==> linked $LINK -> $BIN_SRC"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "==> NOTE: $BIN_DIR is not on your PATH. Add it, e.g.:"
     echo "     echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc   # or ~/.zshrc / fish config" ;;
esac

echo "==> done. Try:  dojo list"
