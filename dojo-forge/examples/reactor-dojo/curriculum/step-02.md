---
step: 2
title: Nonblocking accept with IO.select
spine: workspace/select_accept.rb
kind: build
reference: select_accept.rb
---

# Step 2 — Nonblocking accept with IO.select

## Frame
Before we juggle many clients, we change *how we wait*. Instead of blocking inside `accept`, we ask
the kernel "is the listening socket ready?" via `IO.select`, and only call `accept_nonblock` when it
says yes. The listener is just another fd that becomes "readable" when a client is waiting — that
realization is the whole trick.

## Diagnose-quiz  (AskUserQuestion)
**Question:** `IO.select([server], nil, nil)` returns. What does it mean that `server` is in the
returned readable array?
- ✅ **A connection is waiting in the backlog, so `accept_nonblock` will return immediately without
  blocking.** The listener is "readable" exactly when there's a client to accept.
- ❌ "There's data to `read` from the server socket." → No — a *listening* socket carries no data;
  readiness means an inbound connection, which you take with `accept`.
- ❌ "The server is ready to send a response." → No — that would be writability, and listeners don't
  send anything; they only hand you client sockets.

## Design-quiz  (AskUserQuestion)
**Question:** Why call `accept_nonblock` instead of plain `accept` here, even though `IO.select` just
told us a client is waiting?
- ✅ **So the loop never blocks: select is the single wait point, and `accept_nonblock` either returns
  a socket or signals "nothing right now" without sleeping.** Keeping every op nonblocking is what
  lets us add many fds later.
- ❌ "`accept` doesn't work after `IO.select`." → It does work, but a stray blocking `accept` would
  reintroduce the freeze we just removed.
- ❌ "`accept_nonblock` is faster." → Not about speed — it's about *never sleeping* anywhere but in
  `IO.select`.

## Spine  (the learner types `workspace/select_accept.rb`, ~14 lines)
Type the wait-then-accept core:
- `TCPServer.new(HOST, PORT)`,
- a `loop` whose body is `readable, _, _ = IO.select([server], nil, nil)`,
- when `server` is in `readable`, call `server.accept_nonblock(exception: false)`; if it returns a
  socket, read one chunk with `read_nonblock` and echo it back, then close (single-shot is fine this
  step — we add persistence next),
- rescue `IO::WaitReadable` (nothing actually ready) by looping again.

**Read first:** `docs/ri-dump/IO_select.txt`, `docs/ri-dump/TCPServer.txt`, `docs/man/select.txt`,
and `docs/man/README.md` (no epoll on macOS — use `IO.select`).

## Agent role
- `[explain]` `IO.select`'s signature `(readers, writers, errors, timeout)` and its
  `[readable, writable, errored]` return; why a listening socket signals readability on a pending
  connection; what `accept_nonblock(exception: false)` returns vs raises.
- `[review]` Is `IO.select` the *only* blocking point? Any accidental blocking `accept`/`read` left?

## Gotchas
- Forgetting `exception: false` (or not rescuing `IO::WaitReadable`) → crashes on a spurious wakeup.
- Reaching for `epoll` — it doesn't exist on macOS; `IO.select` is the portable readiness call.

## Success check
`ruby workspace/select_accept.rb`, then `printf 'hi\n' | nc 127.0.0.1 3000` → echoes `hi`. The
learner should confirm the process is asleep in `IO.select` (not spinning) when idle.

## Reflect-quiz  (AskUserQuestion)
**Question:** We can now wait on the listener without blocking. What's the minimal change to also
watch *connected clients* for incoming data?
- ✅ **Put every client socket into the same `IO.select` readers array alongside the listener, and
  react to whichever fds come back ready.** One select call watching all of them.
- ❌ "Open a thread per client to read them." → That abandons the reactor model; we keep one thread.
- ❌ "Poll each client with a separate `IO.select` in turn." → That serializes the waiting again —
  the point is one select over the whole set.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Say: *"Now we widen the select set from just the
listener to the listener plus every client — that's the reactor."* Point them to **Step 3** and run
`/reactor-dojo:next`.
