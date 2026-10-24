#!/usr/bin/env bash
# Build and install (or update) the native `brk` CLI from this checkout.
#
#   gh repo clone geeksilva97/brk ~/.brk && ~/.brk/install.sh
#
# Re-running pulls the latest (tool + dojos), builds and re-links. Nothing is
# published anywhere; the installed binary uses the content in this checkout.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin/brk"
BIN_DIR="${BRK_BIN_DIR:-$HOME/.local/bin}"
LINK="$BIN_DIR/brk"

command -v cargo >/dev/null 2>&1 || { echo "install: Rust/Cargo (>=1.89) is required to build brk." >&2; exit 1; }

# If this is a git checkout, fetch the latest before linking.
# (BRK_SKIP_PULL lets the test suite link without touching the repo's git state.)
if [ -d "$REPO_DIR/.git" ] && [ -z "${BRK_SKIP_PULL:-}" ]; then
  echo "==> updating $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only --quiet || echo "   (pull skipped — local changes or no upstream)"
fi

echo "==> building native brk"
cargo build --locked --release --manifest-path "$REPO_DIR/Cargo.toml" --target-dir "$REPO_DIR/target"
# Replace only after a successful build; keep a working installation on failure.
staged="$(mktemp "$REPO_DIR/bin/.brk-install.XXXXXX")"
trap 'rm -f "$staged"' EXIT
cp "$REPO_DIR/target/release/brk" "$staged"
chmod +x "$staged"
mv -f "$staged" "$BIN_SRC"
mkdir -p "$BIN_DIR"
ln -sf "$BIN_SRC" "$LINK"
echo "==> linked $LINK -> $BIN_SRC"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "==> NOTE: $BIN_DIR is not on your PATH. Add it, e.g.:"
     echo "     echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc   # or ~/.zshrc / fish config" ;;
esac

echo "==> done. Try:  brk list"
