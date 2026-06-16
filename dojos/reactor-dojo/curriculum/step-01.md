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

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding in their own words. Each answer is scored 1–5 with feedback given. If score < 3, the tutor re-explains and asks again — nonsense, vague, or 'I don't know' answers do NOT count. No advancement without understanding. -->

**Question 1:** You start the server, connect with one client, and it echoes fine. A second client connects but gets no response at all — not even a refusal. Why does it just hang?

A good answer covers: the process is blocked inside `read`/`readpartial` for client 1 and never loops back to `accept`; client 2 isn't refused — the kernel parks it in the listen backlog until someone calls `accept` again, which never happens while stuck on client 1.

**Question 2:** In this blocking design, where does the process spend its time when one client is connected but idle (not sending anything)?

A good answer covers: asleep inside a blocking `read`/`readpartial` on that one socket — doing nothing for anyone else; the problem isn't CPU usage, it's that the process can only wait on one file descriptor at a time.

**Question 3:** What is the *one* blocking call we'll have to eliminate to serve two clients at once without threads or processes?

A good answer covers: the blocking wait on a single socket — we need to wait on *all* sockets at once and only touch the ones that are ready; `IO.select` is the mechanism that provides this.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Say: *"The fix is to never block on one socket.
Next we meet `IO.select` — ask the kernel which sockets are ready — starting with just the listener."*
Then point them to **Step 2** and run `/reactor-dojo:next`.
