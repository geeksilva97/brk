#!/usr/bin/env bash
# Build the offline docs bundle into ./docs in the current project directory.
# Both the human and the (possibly offline) agent grep this instead of the web.
# Idempotent: re-run any time. Each item is best-effort (|| true) so a missing
# source never aborts the whole bundle.
#
# This is the reactor-dojo bundle for a reactor-based server in Ruby (Ruby). The forge fills in the
# topic-specific doc-gathering below; the INDEX + committed-cheatsheet copy are generic.
set -uo pipefail

OUT="${1:-./docs}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

# --- Topic-specific doc gathering ---------------------------------------------------
mkdir -p "$OUT/ri-dump" "$OUT/man"

echo "==> ri dumps (Ruby core + stdlib)"
ri_dump() {
  local out="$OUT/ri-dump/$1.txt"; shift
  local name
  for name in "$@"; do
    if ri --no-pager "$name" > "$out" 2>/dev/null && [[ -s "$out" ]]; then return; fi
  done
  rm -f "$out"; echo "   (ri: $1 unavailable on this Ruby)"
}
ri_dump IO IO
ri_dump IO_select "IO.select" IO
ri_dump Socket Socket
ri_dump BasicSocket BasicSocket
ri_dump TCPServer TCPServer
ri_dump TCPSocket TCPSocket
ri_dump IO_Buffer "IO::Buffer"

echo "==> man pages (BSD/macOS)"
for p in select poll kqueue kevent socket accept listen setsockopt fcntl; do
  if man "$p" 2>/dev/null | col -b > "$OUT/man/${p}.txt" 2>/dev/null && [[ -s "$OUT/man/${p}.txt" ]]; then
    :
  else
    rm -f "$OUT/man/${p}.txt"
    echo "   (man: $p not present)"
  fi
done

cat > "$OUT/man/README.md" <<'EOF'
# Reading these man pages — macOS reality

- **There is no `epoll`** on macOS. epoll is Linux-only; the BSD/macOS equivalent is
  `kqueue(2)`/`kevent(2)`. For a reactor you don't call either directly — Ruby's `IO.select`
  abstracts over the readiness primitive for you. Reach for `IO.select`, not raw epoll/kqueue.
- A reactor never *blocks* on a single fd. Sockets must be put in nonblocking mode
  (`sock.fcntl(Fcntl::F_SETFL, ...)` or use the `*_nonblock` methods) so `IO.select` is the only
  place you wait.
EOF

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
# Offline docs bundle — index (reactor-dojo)

Everything here is greppable: `grep -ri "<thing>" docs/`. No internet needed (or allowed).

| If you need… | Read |
|---|---|
| Sockets, accept, listen | `man/socket.txt`, `man/accept.txt`, `man/listen.txt`, `ri-dump/Socket.txt`, `ri-dump/TCPServer.txt` |
| Nonblocking reads/writes | `ri-dump/IO.txt`, `ri-dump/BasicSocket.txt` (accept_nonblock, read_nonblock, write_nonblock) |
| Readiness multiplexing (select, NOT epoll) | `ri-dump/IO_select.txt`, `man/select.txt`, `man/poll.txt`, `man/kqueue.txt`, `man/README.md` |
| Setting a socket nonblocking | `man/fcntl.txt`, `man/setsockopt.txt` |
| The reactor loop shape (GIVEN) | `reactor-loop-cheatsheet.md` |
| macOS gotchas (no epoll) | `man/README.md` |
EOF

echo "==> Done. Bundle at: $OUT"
echo "    Verify: ls $OUT && cat $OUT/INDEX.md"
