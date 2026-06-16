---
step: 5
title: "Backpressure: writes that would block"
spine: workspace/reactor_writes.rb
kind: build
reference: reactor_writes.rb
---

# Step 5 — Backpressure: writes that would block

## Frame
The reactor's promise is "never block anywhere but `IO.select`." We honored it for reads. But
`write_nonblock` to a client whose receive buffer is full raises `IO::WaitWritable` — and if we'd
used a blocking `write`, one slow consumer would freeze every other connection. The fix uses the
*writers* array of `IO.select`: buffer the unsent bytes and only push them when the socket reports
writable.

## Diagnose-quiz  (AskUserQuestion)
**Question:** `write_nonblock(data)` returns `12` when `data` was 50 bytes (or raises
`IO::WaitWritable`). What does that mean and what do you do?
- ✅ **Only 12 bytes made it into the kernel buffer; you must keep the remaining 38, stop writing, and
  resume when `IO.select` reports the socket *writable*.** Partial writes are normal on a full buffer.
- ❌ "It failed; resend all 50." → No — the 12 were sent; resending duplicates them. Track the offset.
- ❌ "Loop calling `write_nonblock` until it all goes." → That busy-spins (and can block); the right
  move is to wait for writability via select.

## Design-quiz  (AskUserQuestion)
**Question:** How does the socket get into the *writers* argument of `IO.select`, and when does it
come back out?
- ✅ **Add the socket to the writers set only while it has pending outbound bytes; drop it once its
  out-buffer is empty.** Watching for writability on an idle socket would make select fire constantly.
- ❌ "Always pass every client as both a reader and a writer." → A socket with nothing to send is
  *always* writable, so select would spin returning it every pass.
- ❌ "Never use the writers set; just retry on the next read." → Then a stuck write never resumes
  until the client happens to send something.

## Spine  (the learner types `workspace/reactor_writes.rb`, ~26 lines)
Extend the Step-4 reactor with an out-buffer per connection:
- per connection keep `{in: +"", out: +""}` (or two hashes),
- on a complete line, instead of `write`, **append** to `out` and try to flush,
- a `flush(io)` helper: `n = io.write_nonblock(out, exception: false)`; if `n` is an Integer, slice
  the sent bytes off `out`; rescue/`:wait_writable` → leave `out` as is,
- build the writers array each pass = the sockets whose `out` is non-empty:
  `readable, writable, _ = IO.select([server, *conns.keys], writers, nil)`; flush each `writable` one.

**Read first:** `docs/reactor-loop-cheatsheet.md` (the "writes that would block" section),
`docs/ri-dump/IO.txt` (`write_nonblock`), `docs/man/select.txt`.

## Agent role
- `[explain]` Partial writes, `IO::WaitWritable`/`exception: false`, and why a socket only belongs in
  the writers set while it has buffered output.
- `[scaffold]` *If needed:* provide the `flush(io)` helper signature and the writers-array
  construction as a skeleton with the offset bookkeeping left as `# TODO`.
- `[review]` Does `out` only shrink by the bytes actually sent? Is the socket removed from the writers
  set when `out` empties? Is `IO.select` still the only wait?

## Gotchas
- Re-sending the whole buffer after a partial write → duplicated bytes.
- Keeping a drained socket in the writers set → select busy-loops on writability.
- Mixing a blocking `write` back in "just for the small responses" → reintroduces the freeze.

## Success check
`ruby workspace/reactor_writes.rb`. Echo still works for normal clients. Simulate a slow consumer
(a client that connects but reads slowly, e.g. `nc` paused with flow control) and a second normal
client: the normal client keeps echoing while the slow one's bytes queue in `out` — **the reactor
never freezes.** The learner explains how the writers set parks the stuck write.

## Reflect-quiz  (AskUserQuestion)
**Question:** With nonblocking reads, buffered writes, and `IO.select` as the only wait, how many OS
threads is this server using to serve, say, 5,000 simultaneous connections?
- ✅ **One.** A single thread multiplexes them all via readiness events — that's the entire payoff of
  the reactor pattern.
- ❌ "One per connection (5,000)." → That's the thread-per-connection model we deliberately avoided.
- ❌ "One per CPU core." → No — the reactor is single-threaded; scaling to cores would mean running
  several reactors, a separate topic.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Say: *"You have a real reactor. Last thing:
*prove* the payoff — hold thousands of idle connections on one thread and watch it not fall over."*
Point them to **Step 6** and run `/reactor-dojo:next`.
