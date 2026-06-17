#!/usr/bin/env bash
# Build the offline docs bundle into ./docs in the current project directory.
# The learner (and the offline tutor) grep this instead of the web. Idempotent:
# re-run any time. Each item is best-effort (|| true) so a missing source never
# aborts the whole bundle.
#
# This is the designme-daddy bundle for a system-design interview (no code). There is no
# language reference or man pages to gather — the entire bundle is the committed
# cheatsheets next to this script (the GIVEN black boxes the learner consults).
set -uo pipefail

OUT="${1:-./docs}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

# --- Topic-specific doc gathering ---------------------------------------------------
# No external reference to gather for a no-code dojo — the bundle IS the cheatsheets.
echo "==> no external reference to gather (no-code dojo); the docs are the committed cheatsheets below"

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
# designme-daddy — offline docs INDEX

This dojo is offline by design. You reason from first principles and from the cheatsheets below —
never from a web search. These cheatsheets are GIVEN: facts and primitives you are handed so you can
spend your thinking on the *design decisions*, not on memorizing numbers. Grep this dir for what you
need.

| Cheatsheet | What it gives you | Use it in phase |
|---|---|---|
| `latency-numbers-cheatsheet.md` | Numbers every engineer should know — cache/RAM/SSD/disk/network costs, ballpark throughput | 2 (estimation), 6–7 (deep dive, scaling) |
| `capacity-estimation-cheatsheet.md` | Powers of 2, seconds-per-day shortcut, QPS / storage / bandwidth formulas, rounding discipline | 2 (estimation) |
| `building-blocks-cheatsheet.md` | What each component does and when to reach for it — LB, cache, CDN, queue, SQL vs NoSQL, sharding, replication, consistent hashing | 4–7 (data model, architecture, deep dive, scaling) |
| `geospatial-cheatsheet.md` | Geohash, quadtree, S2 cells — how each indexes location and their trade-offs | 6 (deep dive: matching) |
| `interview-framework-cheatsheet.md` | The 8-phase interview framework and what each phase delivers | every phase (orientation) |

## How to use these
- These are GIVEN facts. Quote a number from the latency sheet; don't re-derive it.
- The *decisions* are yours: which storage engine, how to shard, what to cache, which trade-off to make.
- If you catch yourself wanting to look something up on the web — that's the jail working. Grep here.
EOF

echo "==> Done. Bundle at: $OUT"
echo "    Verify: ls $OUT && cat $OUT/INDEX.md"
