---
step: 3
title: The reactor: one loop, many clients
spine: workspace/reactor.rb
kind: build
reference: reactor.rb
---

# Step 3 — The reactor: one loop, many clients

## Frame
This is the step the whole course builds toward. We put the listener AND every connected client into a
single `IO.select`, then react to whichever fds are ready: accept on the listener, echo on a client.
One thread, no fork, no blocking — yet two `nc` sessions stay live at the same time. The hang from
Step 1 is gone.



## Spine  (the learner types `workspace/reactor.rb`, ~22 lines)
Type the reactor core (copy the *shape* from the cheatsheet, write the logic yourself):
- `server = TCPServer.new(HOST, PORT)` and `clients = []` (just the sockets this step),
- `loop` → `readable, _, _ = IO.select([server, *clients])`,
- `readable.each` → if `io == server`: `client = server.accept_nonblock(exception: false)`; push it
  onto `clients` unless it's `:wait_readable`. Else: `read_nonblock(4096)` and `write` it back;
  rescue `EOFError`/`Errno::ECONNRESET` by closing the socket and deleting it from `clients`.

**Read first:** `docs/reactor-loop-cheatsheet.md` (the GIVEN shape), `docs/ri-dump/IO_select.txt`.

## reactor-loop-cheatsheet.md is GIVEN, not assumed
The learner is **not expected to invent** the `IO.select` calling convention.
`docs/reactor-loop-cheatsheet.md` is a complete worked skeleton of the loop; the learner copies its
*shape* and writes the application logic (accept vs echo, the clean-up). Tell them this up front so
they don't feel they're missing prerequisite knowledge.

## Agent role
- `[explain]` Walk the learner through `docs/reactor-loop-cheatsheet.md`: the single wait point, the
  branch on `io == server`, and why closed fds must leave the set. The loop shape is GIVEN; the
  lesson is the dispatch logic.
- `[scaffold]` *If the learner is new to this:* write the loop frame (the `IO.select` call + the
  `readable.each do |io|` with `if io == server … else … end` and an `ensure`-style cleanup) into
  `workspace/reactor.rb`, leaving `# TODO: accept` and `# TODO: echo/close` for the learner.
- `[review]` Is `IO.select` the only wait? Are dead sockets removed from `clients` before the next
  select? Any blocking `accept`/`read` sneaking back in?

## Gotchas
- Leaving a closed socket in `clients` → busy-loop (select reports it ready every pass).
- Blocking `accept` instead of `accept_nonblock` → one slow connect freezes the loop.
- Forgetting `*clients` (splat) so clients never get watched.

## Success check
`ruby workspace/reactor.rb`, then open **two** `nc 127.0.0.1 3000` sessions at once: both echo
independently and neither hangs. Close one; the other keeps working. The learner explains why the
Step-1 hang is gone.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding in their own words. Each answer is scored 1–5 with feedback given. If score < 3, the learner may retry once. -->

**Question 1:** In `readable, _, _ = IO.select([server, *clients], nil, nil)`, the returned `readable` array can contain the listener and several clients at once. How should the loop treat that array?

A good answer covers: iterate it and branch per fd — if it's the listener, `accept`; otherwise read/echo that client; handle every ready fd before calling `IO.select` again; select reports *all* currently-ready fds, so service them all then wait again.

**Question 2:** When a client disconnects (you read EOF), what must happen *before* the next `IO.select`?

A good answer covers: close the socket AND remove it from the clients set, so it isn't passed to `IO.select` again; a closed/EOF fd left in the set makes select report it ready forever and you spin.

**Question 3:** A client sends `"hel"` then pauses, then sends `"lo\n"`. With our current per-read echo, what happens — and what does that tell us we're missing?

A good answer covers: we echo `"hel"` then later `"lo\n"` as two separate reads — fine for echo, but we have nowhere to *accumulate* a partial message, so any protocol that needs a full line/frame is broken; we need per-connection state (a buffer).

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Say: *"Echo survives fragmentation by luck. Real
protocols don't — next we give each connection its own buffer so the reactor can remember half-read
messages."* Point them to **Step 4** and run `/reactor-dojo:next`.
