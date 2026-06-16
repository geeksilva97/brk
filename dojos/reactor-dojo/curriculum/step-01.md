---
step: 1
title: Blocking accept loop
spine: workspace/blocking_echo.rb
kind: build
reference: blocking_echo.rb
---

# Step 1 — Blocking accept loop

## Frame
A reactor exists to solve one problem, and you have to *feel* that problem before the solution makes
sense. So first we build the naive thing: a server that accepts one client, talks to it, and only
then loops back to accept the next. By the end you'll see exactly why a single slow client freezes
everyone — that freeze is the reason the next five steps exist.

## Diagnose-quiz  (AskUserQuestion)
**Question:** You start the server, connect with one `nc`, and it echoes fine. You open a *second*
`nc` while the first is still connected — and it just hangs. Why?
- ✅ **The process is blocked inside `read` (or back in a blocking `accept`) for client 1 and never
  services client 2.** Confirm, then add: client 2 isn't refused — the kernel parks it in the listen
  backlog until someone calls `accept` again, which never happens while we're stuck on client 1.
- ❌ "`accept` can only return once." → No — `accept` is in a loop and returns a *new* socket each
  time; the problem is we never *get back* to it because the read blocks.
- ❌ "The OS refuses the second connection." → No — it's queued in the backlog; it'll be served the
  instant we reach `accept` again.

## Design-quiz  (AskUserQuestion)
**Question:** Where, in this blocking design, does the process spend its time when one client is
connected but idle (not sending anything)?
- ✅ **Asleep inside a blocking `read`/`readpartial` on that one socket — doing nothing for anyone
  else.** That single blocking call is the whole bottleneck.
- ❌ "Spinning in a busy loop checking for data." → No — a blocking read sleeps; it doesn't spin. The
  problem isn't CPU, it's that it can only wait on one fd.
- ❌ "In `accept`, ready for the next client." → No — we don't reach `accept` again until client 1
  disconnects.

## Spine  (the learner types `workspace/blocking_echo.rb`, ~12 lines)
Type it by hand — this whole spine is the lesson:
- read `HOST`/`PORT` from ENV with defaults `127.0.0.1` / `3000`,
- `TCPServer.new(HOST, PORT)`,
- a `loop` that calls `accept` (blocking), then an inner loop reading with `readpartial(4096)` and
  writing the bytes back, rescuing `EOFError` to close and return to `accept`,
- print `"listening on #{PORT}"` at startup.

**Read first:** `docs/man/accept.txt`, `docs/ri-dump/TCPServer.txt`, `docs/ri-dump/IO.txt`.

## Agent role
- `[explain]` From `docs/ri-dump/TCPServer.txt` + `docs/man/accept.txt`: what `accept` returns, why
  it blocks, and what `readpartial` raises at end-of-stream (`EOFError`).
- `[review]` Check every accepted socket gets closed (fd leak), and confirm the structure only
  returns to `accept` after a client disconnects.

## Gotchas
- Forgetting to `close` the accepted socket → file-descriptor leak.
- Using `gets` (line-buffered) instead of `readpartial` — note the difference.

## Success check
1. `ruby workspace/blocking_echo.rb` → prints `listening on 3000`.
2. `printf 'hi\n' | nc 127.0.0.1 3000` → prints `hi`.
3. Open a second `nc 127.0.0.1 3000` while the first is held open → **it hangs.**

The learner must explain *why* it hangs before the step counts as done.

## Reflect-quiz  (AskUserQuestion)
**Question:** What is the *one* blocking call we'll have to eliminate to serve two clients at once
without threads or processes?
- ✅ **The blocking wait on a single socket — we need to wait on *all* sockets at once and only touch
  the ones that are ready.** That's exactly what `IO.select` gives us.
- ❌ "We need a thread per connection." → That's a different model; the reactor's whole point is one
  thread. We'll do it without threads.
- ❌ "We need to `fork` per connection." → Also a different model; the reactor avoids per-connection
  processes entirely.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Say: *"The fix is to never block on one socket.
Next we meet `IO.select` — ask the kernel which sockets are ready — starting with just the listener."*
Then point them to **Step 2** and run `/reactor-dojo:next`.
