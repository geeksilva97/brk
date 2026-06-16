---
step: 1
title: Raw TCP echo server
chapter: 1
session: 0
spine: workspace/echo.rb
kind: tcp
reference: first_socket.rb
---

# Step 1 — Raw TCP echo server

## Frame
Every web server, underneath all the layers, is a program that opens a socket, waits for a client,
and reads and writes bytes. Before HTTP, before Rack, before concurrency — there is `accept`. We'll
build the smallest possible server: an echo server that serves exactly one client at a time. By the
end you'll *feel* its fatal limitation, and that limitation is the reason the other 16 steps exist.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** You start the server, connect with one `nc`, and it echoes fine. You open a *second*
`nc` while the first is still connected — and it just hangs. Why?

A good answer covers: the process is busy in the read loop for client 1 and never returns to
`accept`; the 2nd connection isn't rejected — the kernel holds it in the *listen backlog* until
someone calls `accept` again, which never happens while client 1 is connected.

## Spine  (the learner types `workspace/echo.rb`, ~12 lines)
Type it by hand — this whole spine is the lesson:
- read `HOST`/`PORT` from ENV with defaults `127.0.0.1` / `3000` (so the same file runs in the
  benchmark cage later),
- `TCPServer.new(HOST, PORT)`,
- a `loop` that calls `accept`, then an inner loop reading with `readpartial(1024)` and writing the
  bytes back, rescuing `EOFError` to close the connection and go back to `accept`,
- print `"listening on #{PORT}"` at startup.

**Read first:** `docs/man/accept.txt`, `docs/man/socket.txt`, `docs/ri-dump/TCPServer.txt`,
`docs/ri-dump/IO.txt` (for `readpartial`).

## Agent role
- `[explain]` From `docs/man/accept.txt` + `docs/ri-dump/TCPServer.txt`: what `accept` returns, why
  it blocks, and what `readpartial` raises at end-of-stream (`EOFError`).
- `[review]` Check for fd leaks (does every accepted socket get closed?) and confirm the structure
  truly returns to `accept` only after a client disconnects.

## Gotchas
- Using `gets` instead of `readpartial` — fine for `nc`, but it's line-buffered; note the difference.
- Forgetting to `close` the accepted socket → file-descriptor leak.
- Binding `0.0.0.0` instead of reading from ENV — we want `127.0.0.1` in dev, `0.0.0.0` only in the cage.

## Success check
1. `ruby workspace/echo.rb` → prints `listening on 3000`.
2. `printf 'hi\n' | nc 127.0.0.1 3000` → prints `hi`.
3. Open a second `nc 127.0.0.1 3000` while the first is held open → **it hangs.**

The learner must explain *why* it hangs before the step counts as done.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** Is the second client hanging a *protocol* problem or a *concurrency* problem?

A good answer covers: it's a concurrency problem — the single process is busy serving client 1;
HTTP/parsing has nothing to do with it. We're not even speaking HTTP yet, and it still hangs.
It's about doing two things at once.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance — never offer a branch among fork/threads/
fibers. Say: *"We'll attack that hang with four concurrency models, in order, starting with the
simplest (fork). But first, one step: real servers speak HTTP — next we wrap this socket in the Rack
contract."* Then point them to **Step 2** and run `/c10k-dojo:next`.
