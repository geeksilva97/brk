#!/usr/bin/env bash
# Build the offline docs bundle into ./docs in the current project directory.
# Both the human and the (possibly offline) agent grep this instead of the web.
# Idempotent: re-run any time. Each item is best-effort (|| true) so a missing
# source never aborts the whole bundle.
#
# This is the replicant bundle for building database replication on SQLite (Ruby). The
# ri dumps below are the stdlib surface the learner needs (sockets, IO, threads); the
# committed cheatsheets ARE the black-box material; the INDEX ties it together.
set -uo pipefail

OUT="${1:-./docs}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

# --- Topic-specific doc gathering ---------------------------------------------------
echo "==> Ruby stdlib ri docs (sockets, IO, concurrency, hashing)"
ri_dump() { # ri_dump <RiTopic> <outfile>
  ri --no-pager "$1" > "$OUT/$2" 2>/dev/null || echo "   (ri for $1 unavailable — see the cheatsheets)"
}
ri_dump "TCPServer"        "ri-TCPServer.txt"
ri_dump "TCPSocket"        "ri-TCPSocket.txt"
ri_dump "Socket"           "ri-Socket.txt"
ri_dump "IO"               "ri-IO.txt"
ri_dump "IO#read"          "ri-IO-read.txt"
ri_dump "IO#write"         "ri-IO-write.txt"
ri_dump "Thread"           "ri-Thread.txt"
ri_dump "Thread::Queue"    "ri-Queue.txt"
ri_dump "Thread::Mutex"    "ri-Mutex.txt"
ri_dump "Marshal"          "ri-Marshal.txt"
ri_dump "Digest::SHA256"   "ri-Digest-SHA256.txt"
ri_dump "Array#pack"       "ri-Array-pack.txt"
ri_dump "String#unpack"    "ri-String-unpack.txt"
ri_dump "SecureRandom"     "ri-SecureRandom.txt"

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
# replicant — offline docs bundle

The dojo is **offline**. Do not reach for the web — everything you need is here. `grep` this file
for the topic, then open the named file.

## Cheatsheets (GIVEN black boxes — copy the shape, don't derive)
| File | What it covers |
|---|---|
| `tcp-sockets-cheatsheet.md` | The raw `TCPServer`/`TCPSocket` API surface — accept, read, write, close. **Not** the framing loop (that is your spine in Step 2). |
| `pack-unpack-cheatsheet.md` | `Array#pack` / `String#unpack` for big-endian 32-bit lengths (`"N"`) — the encoding calls, not the framing logic. |
| `sqlite3-ruby-cheatsheet.md` | Using the `sqlite3` gem from Ruby: open a DB, `execute` with bind params, read rows, and content-checksum a database for the convergence checks. |
| `wire-protocol-cheatsheet.md` | The agreed message envelope every node speaks (fields, message types, JSON payload shape) so all steps interoperate. |

## Ruby stdlib reference (ri dumps)
| File | Topic |
|---|---|
| `ri-TCPServer.txt` / `ri-TCPSocket.txt` / `ri-Socket.txt` | Listening, accepting, connecting sockets |
| `ri-IO.txt` / `ri-IO-read.txt` / `ri-IO-write.txt` | Reading/writing byte streams (partial reads!) |
| `ri-Thread.txt` / `ri-Queue.txt` / `ri-Mutex.txt` | Concurrency: the single-writer queue |
| `ri-Array-pack.txt` / `ri-String-unpack.txt` | Binary length framing |
| `ri-Marshal.txt` / `ri-Digest-SHA256.txt` / `ri-SecureRandom.txt` | Serialization, checksums, request IDs |

## The rules
- Offline: no WebFetch/WebSearch (the guard blocks them). Only `localhost`/`127.0.0.1` is reachable — that is where your own nodes listen.
- Pinned deps: the `sqlite3` gem (vendored) + Ruby stdlib. No `gem install` (the guard blocks it).
- You type the spine. The tutor explains, reviews, and writes only the files marked `[glue]`/`[scaffold]`.
EOF

echo "==> Done. Bundle at: $OUT"
echo "    Verify: ls $OUT && cat $OUT/INDEX.md"
