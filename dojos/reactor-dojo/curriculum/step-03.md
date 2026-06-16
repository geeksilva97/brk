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

## Diagnose-quiz  (AskUserQuestion)
**Question:** In `readable, _, _ = IO.select([server, *clients], nil, nil)`, the returned `readable`
array can contain the listener and several clients at once. How should the loop treat that array?
- ✅ **Iterate it and branch per fd: if it's the listener, `accept`; otherwise read/echo that client
  — handling every ready fd before calling `IO.select` again.** Select reports *all* currently-ready
  fds; you service them, then wait again.
- ❌ "Handle only the first ready fd, then call `IO.select` again." → Wasteful and can starve fds;
  service everything select reported.
- ❌ "Call `IO.select` once per fd to find out which is ready." → That defeats the purpose — one
  select reports the whole ready set.

## Design-quiz  (AskUserQuestion)
**Question:** When a client disconnects (you read EOF), what must happen *before* the next
`IO.select`?
- ✅ **Close the socket AND remove it from the clients set, so it isn't passed to `IO.select` again.**
  A closed/EOF fd left in the set makes select report it ready forever and you spin.
- ❌ "Just close it; select will skip closed sockets." → No — passing a closed fd to `IO.select`
  raises (or busy-loops); you must drop it from the array.
- ❌ "Nothing — let it time out." → It won't time out; it'll be reported ready every iteration.

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

## Reflect-quiz  (AskUserQuestion)
**Question:** A client sends `"hel"` then pauses, then sends `"lo\n"`. With our current per-read echo,
what happens — and what does that tell us we're missing?
- ✅ **We echo `"hel"` then later `"lo\n"` as two separate reads — fine for echo, but we have nowhere
  to *accumulate* a partial message, so any protocol that needs a full line/frame is broken. We need
  per-connection state.** That's the next step.
- ❌ "`read_nonblock` waits for the whole message." → No — it returns whatever bytes are available
  right now, possibly a fragment.
- ❌ "The fragments are lost." → No — we read both, just with no buffer tying them together.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Say: *"Echo survives fragmentation by luck. Real
protocols don't — next we give each connection its own buffer so the reactor can remember half-read
messages."* Point them to **Step 4** and run `/reactor-dojo:next`.
