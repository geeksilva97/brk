#!/usr/bin/env bash
# Build the offline docs bundle into ./docs in the current project directory.
# Both the human and the (possibly offline) agent grep this instead of the web.
# Idempotent: re-run any time. Each item is best-effort (|| true) so a missing
# source never aborts the whole bundle.
#
# This is the systeminterview bundle for System Design Interview (Google Meet).
set -uo pipefail

OUT="${1:-./docs}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

# --- Topic-specific doc gathering ---------------------------------------------------
# Copy the ground-truth reference into the bundle (the agent can reference it
# during evaluation in Step 7; the guard hook blocks the learner from reading
# curriculum/reference/ground-truth.md directly).
echo "==> reference materials"
ROOT="$(cd "$HERE/../.." && pwd)"
if [[ -f "$ROOT/curriculum/reference/ground-truth.md" ]]; then
  cp "$ROOT/curriculum/reference/ground-truth.md" "$OUT/ground-truth.md"
  echo "   copied ground-truth.md"
fi

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
# systeminterview — Offline Docs Bundle

Reference material for the System Design Interview dojo (offline by design).

## Files

| File | What it covers |
|------|---------------|
| `webrtc-cheatsheet.md` | WebRTC fundamentals: SDP, ICE, DTLS, DataChannel, SFU/MCU topology |
| `capacity-cheatsheet.md` | Back-of-the-envelope estimation: bandwidth, servers, TURN costs, storage |
| `ground-truth.md` | Complete reference design for Google Meet (evaluation reference, Step 7 only) |

## How to use

- `grep -i webrtc docs/` — find WebRTC-related info
- `grep -i bandwidth docs/` — find capacity estimation references
- Open `docs/webrtc-cheatsheet.md` for WebRTC fundamentals
- Open `docs/capacity-cheatsheet.md` for estimation patterns and reference numbers
EOF

echo "==> Done. Bundle at: $OUT"
echo "    Verify: ls $OUT && cat $OUT/INDEX.md"