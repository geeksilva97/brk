#!/usr/bin/env bash
# Build the offline docs bundle into ./docs in the current project directory.
# Both the human and the (possibly offline) agent grep this instead of the web.
# Idempotent: re-run any time. Each item is best-effort (|| true) so a missing
# man page or ri index never aborts the whole bundle.
set -uo pipefail

OUT="${1:-./docs}"
mkdir -p "$OUT/ri-dump" "$OUT/man"

echo "==> ri dumps (Ruby core + stdlib)"
# ri_dump <outname> <candidate ri name>...  — write first candidate that yields
# non-empty output to ri-dump/<outname>.txt; drop empties. Filenames use single
# underscores so they match INDEX.md (e.g. Fiber_Scheduler, IO_Buffer).
ri_dump() {
  local out="$OUT/ri-dump/$1.txt"; shift
  local name
  for name in "$@"; do
    if ri --no-pager "$name" > "$out" 2>/dev/null && [[ -s "$out" ]]; then return; fi
  done
  rm -f "$out"; echo "   (ri: $1 unavailable on this Ruby)"
}
ri_dump Socket Socket
ri_dump BasicSocket BasicSocket
ri_dump TCPServer TCPServer
ri_dump TCPSocket TCPSocket
ri_dump IO IO
ri_dump IO_Buffer "IO::Buffer"
ri_dump Thread Thread
ri_dump Mutex Mutex "Thread::Mutex"
ri_dump Queue "Thread::Queue" Queue
ri_dump ConditionVariable "Thread::ConditionVariable" ConditionVariable
ri_dump Fiber Fiber
ri_dump Fiber_Scheduler "Fiber::Scheduler"
ri_dump Enumerator Enumerator
ri_dump Process Process
ri_dump Process_Status "Process::Status"
ri_dump Signal Signal
ri_dump Ractor Ractor

echo "==> man pages (BSD/macOS)"
for p in socket bind listen accept connect fork kqueue kevent \
         select poll setsockopt getsockopt sigaction sigprocmask signal; do
  if man "$p" 2>/dev/null | col -b > "$OUT/man/${p}.txt" 2>/dev/null && [[ -s "$OUT/man/${p}.txt" ]]; then
    :
  else
    rm -f "$OUT/man/${p}.txt"
    echo "   (man: $p not present — expected for epoll-family on macOS)"
  fi
done

cat > "$OUT/man/README.md" <<'EOF'
# Reading these man pages — macOS reality

This bundle is built on macOS (BSD man pages). Two traps that bite both humans
and AI models:

- **There is no `epoll`.** epoll is Linux-only. The macOS/BSD equivalent is
  `kqueue(2)` / `kevent(2)`. Ruby's `IO.select` and `Fiber::Scheduler` abstract
  over kqueue for you — you almost never call it directly.
- **`signal` is section 3 here, not 7.** It's `signal(3)` on macOS. For changing
  a handler, see `sigaction(2)`.

If you (or a small local model) start writing `epoll`/`epoll_create`, stop — that
code can't run on this machine. Use the Ruby-level abstraction instead.
EOF

echo "==> Rack SPEC + protocol-http1 source pointers"
rack_spec="$(gem contents rack 2>/dev/null | grep -iE 'SPEC\.rdoc$' | head -1 || true)"
if [[ -n "$rack_spec" && -f "$rack_spec" ]]; then
  cp "$rack_spec" "$OUT/rack-3.2-SPEC.rdoc"
else
  echo "   (rack SPEC.rdoc not found via 'gem contents rack' — install rack or copy manually)"
fi
# The cheatsheet is a committed, complete worked example — copy it verbatim so it's
# always present and never drifts. (Single source of truth: env/docs/protocol-http1-cheatsheet.md)
if [[ -f "$(dirname "$0")/protocol-http1-cheatsheet.md" ]]; then
  cp "$(dirname "$0")/protocol-http1-cheatsheet.md" "$OUT/protocol-http1-cheatsheet.md"
else
  echo "   (protocol-http1-cheatsheet.md missing next to build-bundle.sh — check the plugin)"
fi

echo "==> INDEX.md"
cat > "$OUT/INDEX.md" <<'EOF'
# Offline docs bundle — index

Everything here is greppable: `grep -ri "<thing>" docs/`. No internet needed (or allowed).

| If you need… | Read |
|---|---|
| Sockets, accept, listen, bind | `man/socket.txt`, `man/accept.txt`, `man/listen.txt`, `ri-dump/Socket.txt`, `ri-dump/TCPServer.txt` |
| Reading/writing a socket | `ri-dump/IO.txt`, `ri-dump/BasicSocket.txt` |
| fork, processes, zombies, reaping | `man/fork.txt`, `ri-dump/Process.txt` |
| Signals | `man/sigaction.txt`, `man/signal.txt` (section 3 on macOS!), `ri-dump/Signal.txt` |
| Threads, the GVL, sync primitives | `ri-dump/Thread.txt`, `ri-dump/Mutex.txt`, `ri-dump/Queue.txt`, `ri-dump/ConditionVariable.txt` |
| Fibers + the scheduler | `ri-dump/Fiber.txt`, `ri-dump/Fiber_Scheduler.txt` |
| Ractors | `ri-dump/Ractor.txt` |
| IO multiplexing (kqueue, NOT epoll) | `man/kqueue.txt`, `man/select.txt`, `man/poll.txt`, `man/README.md` |
| The HTTP parser API | `protocol-http1-cheatsheet.md` |
| Rack rules (env, [status,headers,body]) | `rack-3.2-SPEC.rdoc` |
| macOS gotchas (no epoll, signal(3)) | `man/README.md` |
EOF

echo "==> Done. Bundle at: $OUT"
echo "    Verify: ls $OUT && grep -ri read_request $OUT | head"
