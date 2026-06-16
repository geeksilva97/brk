---
step: 4
title: Per-connection state and partial reads
spine: workspace/reactor.rb
kind: build
reference: reactor.rb
---

# Step 4 — Per-connection state and partial reads

## Frame
One thread is handling many half-finished conversations. The call stack can't hold "where each
connection was" — the moment we return to `IO.select`, that context is gone. So state must live in a
hash keyed by the socket. We'll switch `clients` from an array to `io => buffer` and only act on a
complete line (terminated by `\n`).



## Spine  (the learner edits `workspace/reactor.rb`, ~10 changed lines)
Evolve Step 3's reactor:
- change `clients = []` to `clients = {}` (`io => +""` buffer; set the buffer when you accept),
- on a readable client: append `read_nonblock(4096)` to `clients[io]`, then **while** the buffer
  contains `"\n"`, slice off the line (through the newline) and `write` it back (the echo of a
  complete line),
- on EOF/reset: `close` and `clients.delete(io)`.

**Read first:** `docs/reactor-loop-cheatsheet.md` (rule 2: state in a hash keyed by IO),
`docs/ri-dump/IO.txt` (`read_nonblock`).

## Agent role
- `[explain]` Why message framing ≠ read boundaries; the buffer-until-delimiter pattern; why the hash
  key is the IO object.
- `[review]` Does the buffer accumulate across reads? Does the `while` drain *all* complete lines in
  the buffer (not just the first)? Is the remainder preserved? Is the buffer deleted on close?

## Gotchas
- Using `if buffer.include?("\n")` instead of `while` → only one line per read drains; a burst backs
  up.
- Resetting the buffer to `""` after a partial line → loses buffered bytes.
- Forgetting to seed `clients[client] = +""` at accept → `nil` buffer on first read.

## Success check
`ruby workspace/reactor.rb`. With `nc 127.0.0.1 3000`, type a line in two bursts
(`printf 'hel'; sleep 1; printf 'lo\n'` piped in) → the server echoes the full `hello` exactly once,
when the newline arrives — not the fragments. Two clients still work concurrently.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding in their own words. Each answer is scored 1–5 with feedback given. If score < 3, the learner may retry once. -->

**Question 1:** Why can't we just use a local variable to remember a connection's partial input between reads, the way a blocking one-client server could?

A good answer covers: because the single loop interleaves many connections — after handling one fd we go back to `IO.select` and lose any stack-local context, so state must be stored *per connection* (keyed by the IO); no stack frame survives across the select.

**Question 2:** A read returns `"abc"` with no newline yet. What's the right move?

A good answer covers: append it to that connection's buffer and do nothing else until a `\n` arrives; then consume up to (and including) the newline and leave any remainder in the buffer; frame on the delimiter, not on the read boundary.

**Question 3:** Our reads are nonblocking and buffered. What's the *symmetric* problem still lurking on the write side?

A good answer covers: a `write` can also fail to complete if the client's receive buffer is full — the socket isn't writable yet; a blocking write there would freeze the whole reactor, so writes need the same nonblocking + buffering treatment.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Say: *"We fixed slow readers. A slow *reader on
the other end* — a client that won't drain — can still block our write. Next: backpressure, using the
writers set of `IO.select`."* Point them to **Step 5** and run `/reactor-dojo:next`.
