#!/usr/bin/env bash
# Build the offline docs bundle into ./docs in the current project directory. Both the learner and
# the agent grep this instead of the web. Idempotent; every item is best-effort.
set -uo pipefail

OUT="${1:-./docs}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

echo "==> Ruby stdlib ri docs (sockets, IO, concurrency, timeouts)"
ri_dump() { # ri_dump <RiTopic> <outfile>
  ri --no-pager "$1" > "$OUT/$2" 2>/dev/null || echo "   (ri for $1 unavailable — see the cheatsheets)"
}
ri_dump "Thread"         "ri-Thread.txt"
ri_dump "Thread::Queue"  "ri-Queue.txt"
ri_dump "Thread::Mutex"  "ri-Mutex.txt"
ri_dump "Timeout"        "ri-Timeout.txt"
ri_dump "Process.clock_gettime" "ri-clock_gettime.txt"

echo "==> cheatsheets"
shopt -s nullglob
for cs in "$HERE"/*-cheatsheet.md; do
  cp "$cs" "$OUT/$(basename "$cs")"
  echo "   copied $(basename "$cs")"
done
shopt -u nullglob

echo "==> INDEX.md"
cat > "$OUT/INDEX.md" <<'EOF'
# replicant-lead — offline docs bundle

The dojo is **offline**. Everything needed is here: `grep` this file for the topic, then open the
named file.

| File | What it covers |
|---|---|
| `baseline-cheatsheet.md` | The GIVEN system: nodes, the two per-node indexes, wire format, client, fault knobs. Start here. |
| `sqlite3-ruby-cheatsheet.md` | The `sqlite3` gem from Ruby: open, execute with binds, read rows. |
| `ri-Thread.txt`, `ri-Queue.txt`, `ri-Mutex.txt` | Ruby concurrency primitives. |
| `ri-Timeout.txt`, `ri-clock_gettime.txt` | Deadlines and monotonic time, for anything that waits or retries. |
EOF
echo "docs bundle ready in $OUT"
