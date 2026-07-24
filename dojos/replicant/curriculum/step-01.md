---
step: 1
title: Listen and frame
spine: workspace/node.rb
kind: build
reference: -
---

# Step 1 — Listen and frame

## Frame
Before anything distributed exists, you need a **node**: a process that listens on a TCP port and can
put a message on the wire. And a message needs a boundary — a way for the receiver to know where it
ends. Today: a listener that accepts one connection and writes back a single **length-prefixed
frame** — `[4-byte big-endian length][payload]`.

## Teach the mechanisms
- **`TCPServer` / `accept`** — bind a host+port and block until a peer connects; `accept` hands you a
  connected `TCPSocket`. See `docs/tcp-sockets-cheatsheet.md`.
- **Why a length prefix?** TCP will hand the receiver a pile of bytes with no markers. If you write
  the byte-count *first*, the reader knows exactly how many bytes the message is. Ask yourself: how
  else could a reader know a message is "done"?
- **Encoding the length** — `[payload.bytesize].pack("N")` produces exactly 4 big-endian bytes. See
  `docs/pack-unpack-cheatsheet.md`. You'll *see* those 4 bytes ahead of your payload in the output.

The raw socket API and `pack` are **GIVEN** (their cheatsheets) — copy the calls, don't derive them.
The lesson you own is *assembling the frame*.

## Spine  (the learner types `workspace/node.rb`, ~15 lines)
Bind `TCPServer` on `127.0.0.1` and a port (say 9001). Accept one connection. Build a payload string,
prefix it with its `bytesize` packed as `"N"`, and write the whole frame to the socket. Close up.
Keep it to the accept-and-write path — nothing reads yet.

**Read first:** `docs/tcp-sockets-cheatsheet.md`, `docs/pack-unpack-cheatsheet.md`.

## Agent role
- `[explain]` Walk the learner through `TCPServer.new`/`accept` and `pack("N")` from the cheatsheets;
  never guess the API, never reach for the web.
- `[glue]` If useful, a 3-line reader one-liner (`nc`/`xxd` or a tiny ruby socket read) to observe
  the bytes — but the framing WRITE stays with the learner.
- `[scaffold]` (none — this spine is small enough to type whole.)
- `[review]` Is the length computed with `bytesize` (not `length`)? Is it packed `"N"`? Is it written
  *before* the payload?

## Gotchas
- No length prefix at all — the receiver can't find the boundary.
- `length` instead of `bytesize` — wrong count for multibyte payloads.
- Not binding to `127.0.0.1` (binds everywhere, or nowhere you expect).
- `EADDRINUSE` — the port is still held by a previous run; pick another or wait.

## Success check
`bundle exec ruby workspace/node.rb` in one shell. In another:
`printf '' | nc 127.0.0.1 9001 | xxd | head` — you should see **4 length bytes** followed by the
payload bytes. Count the payload bytes; they must equal the number in the prefix.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
If you forgot the length prefix and just wrote the payload, what would a receiver on the other end
have no way of knowing? Have them reason from the bytes they actually saw in `xxd`.

**Quiz topic 2 — Design:**
Why prefix the *length* rather than end each message with a delimiter like a newline? Push on what
happens when the payload itself contains that delimiter.

**Quiz topic 3 — Reflect:**
In one sentence, what is "a node" in this system, and what did adding the length prefix buy you?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. They can *write* a frame — next they must
*read* one back out of a raw byte stream. Then point them to **Step 2** and run `/replicant:next`.
Next: Read frames from the stream.
