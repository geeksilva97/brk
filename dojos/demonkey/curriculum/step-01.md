---
step: 1
title: Raw TCP echo server
spine: workspace/echo.rb
kind: tcp
reference: echo.rb
---

# Step 1 — Raw TCP echo server

## Frame
Every web server, underneath all the layers, is a program that opens a socket, waits for a client,
and reads and writes bytes. Before HTTP, before Rack, before concurrency — there is `accept`. We'll
build the smallest possible server: an echo server that serves exactly one client at a time. By the
end you'll *feel* its fatal limitation, and that limitation is the reason the rest of the course
exists.

## Teach the mechanism  (sockets are NEW — explain before they build)
These are new to a Ruby-only learner — teach each with a one-liner or a leading question, then point
at the doc; don't quiz them yet:
- `TCPServer.new(HOST, PORT)` opens a **listening** socket bound to a port.
- `accept` **blocks** until a client connects, then returns a *new* socket for that one client. It's
  called in a loop — each call hands you the next connection.
- `readpartial(1024)` reads up to N bytes as they arrive (not line-buffered); it raises `EOFError`
  when the client closes — that's your signal to close this connection and loop back to `accept`.

**How you'll validate it:** once it's running you'll connect with `nc` (a raw TCP client — full intro
when we run it) and watch a line you type come straight back. Then you'll open a *second* `nc` and
discover the limitation for yourself.

**Read first:** `docs/man/accept.txt`, `docs/man/socket.txt`, `docs/ri-dump/TCPServer.txt`,
`docs/ri-dump/IO.txt` (for `readpartial`).

## Spine  (the learner types `workspace/echo.rb`, ~12 lines)
Type it by hand — this whole spine is the lesson:
- read `HOST`/`PORT` from ENV with defaults `127.0.0.1` / `3000`,
- `TCPServer.new(HOST, PORT)`,
- a `loop` that calls `accept`, then an inner loop reading with `readpartial(1024)` and writing the
  bytes back, rescuing `EOFError` to close the connection and go back to `accept`,
- print `"listening on #{PORT}"` at startup.

## Agent role
- `[explain]` From `docs/man/accept.txt` + `docs/ri-dump/TCPServer.txt`: what `accept` returns, why
  it blocks, and what `readpartial` raises at end-of-stream (`EOFError`).
- `[review]` Check for fd leaks (does every accepted socket get closed?) and confirm the structure
  truly returns to `accept` only after a client disconnects.

## Gotchas
- Using `gets` instead of `readpartial` — fine for `nc`, but it's line-buffered; note the difference.
- Forgetting to `close` the accepted socket → file-descriptor leak.
- Binding `0.0.0.0` instead of reading from ENV — keep `127.0.0.1` in dev.

## Success check  (local — nc only)
1. `ruby workspace/echo.rb` → prints `listening on 3000`.
2. `printf 'hi\n' | nc 127.0.0.1 3000` → prints `hi`.
3. Open a second `nc 127.0.0.1 3000` while the first is held open → **it hangs.**

The learner must explain *why* it hangs before the step counts as done.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks open-ended questions; the learner types their understanding in their own words.
     Scored 1–5; feedback given; the tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

Only now, with the hang seen first-hand, run these as comprehension checks — phrase them about what
the learner just watched, never as a prediction.

**Question 1:** You just watched it: the first `nc` echoes fine, and a second `nc` opened while the
first is still connected *hangs* with no echo. Why?
A good answer covers: the process is busy in the read loop for client 1 and never returns to
`accept`; the 2nd connection isn't rejected — the kernel holds it in the listen backlog until
someone calls `accept` again.

**Question 2:** Is the second client hanging a *protocol* problem or a *concurrency* problem?
A good answer covers: concurrency — the single process is busy serving client 1; HTTP/parsing has
nothing to do with it; it's about doing two things at once.

**Next:** before we attack the hang, real servers speak HTTP — Step 2 wraps this socket in the Rack
contract. `/demonkey:next`.
