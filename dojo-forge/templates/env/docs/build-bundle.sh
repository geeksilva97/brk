#!/usr/bin/env bash
# Build the offline docs bundle into ./docs in the current project directory.
# Both the human and the (possibly offline) agent grep this instead of the web.
# Idempotent: re-run any time. Each item is best-effort (|| true) so a missing
# source never aborts the whole bundle.
#
# This is the {{PLUGIN_NAME}} bundle for {{TOPIC}} ({{LANGUAGE}}). The forge fills in the
# topic-specific doc-gathering below; the INDEX + committed-cheatsheet copy are generic.
set -uo pipefail

OUT="${1:-./docs}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

# --- Topic-specific doc gathering ---------------------------------------------------
# (ri dumps, man pages, generated reference, etc. — filled in by the forge per topic.)
{{BUNDLE_GATHER}}

# --- Committed cheatsheets ----------------------------------------------------------
# Anything the learner is GIVEN as a black box ships as a complete committed cheatsheet
# next to this script and is copied verbatim so it's always present and never drifts.
echo "==> cheatsheets"
shopt -s nullglob
for cs in "$HERE"/*-cheatsheet.md; do
  cp "$cs" "$OUT/$(basename "$cs")"
  echo "   copied $(basename "$cs")"
done
shopt -u nullglob

# --- INDEX --------------------------------------------------------------------------
echo "==> INDEX.md"
cat > "$OUT/INDEX.md" <<'EOF'
{{INDEX_BODY}}
EOF

echo "==> Done. Bundle at: $OUT"
echo "    Verify: ls $OUT && cat $OUT/INDEX.md"
