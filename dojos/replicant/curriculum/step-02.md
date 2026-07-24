---
step: 2
title: Read frames from the stream
spine: workspace/framing.rb
kind: build
reference: -
---

# Step 2 — Read frames from the stream

## Frame
Here is the lesson the whole transport rests on: **TCP is a byte stream, not a message stream.** The
single frame you wrote in Step 1 may reach a reader split across two reads; two frames may arrive
glued into one read. The socket preserves *bytes and order* — never *message boundaries*. You must
recover them. Build the read side that reassembles whole frames no matter how the bytes are chopped.

## Teach the mechanisms
- **`read(n)` vs `readpartial`** — `read(n)` blocks until it has exactly `n` bytes (short only at
  EOF); `readpartial(max)` returns whatever is buffered *right now* (1..max). `docs/tcp-sockets-cheatsheet.md`
  spells out both. Either can build framing; the point is *you* decide how many bytes to pull.
- **The frame protocol** — read the 4-byte length, `unpack1("N")` it, then read exactly that many
  payload bytes. That's one message. `docs/pack-unpack-cheatsheet.md`.
- **Split and coalesced arrivals** — a robust reader keeps a buffer and pulls out *every* complete
  frame available, keeping the leftover bytes for next time. You'll verify by forcing both cases.

## Spine  (the learner types `workspace/framing.rb`, ~25 lines)
Write a `read_frame(io)` that reads 4 length bytes, decodes `"N"`, then reads exactly that many bytes
and returns the payload. Then make it survive the stream: either loop `read(exact_n)` correctly, or
keep a buffer and extract as many whole frames as it holds, retaining the remainder. Prove it against
*both* a coalesced write and a split write.

**Read first:** `docs/tcp-sockets-cheatsheet.md`, `docs/pack-unpack-cheatsheet.md`.

## Agent role
- `[explain]` Clarify `read(n)`'s exact-vs-EOF behavior and how `unpack1("N")` reverses the Step-1
  prefix.
- `[glue]` Write a small test driver that opens a socket and (a) sends two frames in ONE `write`,
  then (b) sends one frame in TWO writes with a pause — so the learner can watch reassembly. The
  driver is glue; the `read_frame`/buffer logic is the learner's.
- `[scaffold]` (none.)
- `[review]` Do they loop until they have all `n` bytes? Do they handle EOF (`nil`/`EOFError`)? On a
  coalesced read, do they keep and parse the *second* frame rather than dropping it?

## Gotchas
- Assuming one `read` returns exactly one message — the core misconception.
- Reading "some" bytes and treating a short read as the whole payload.
- Losing the bytes past the first frame when two arrive together.
- Not distinguishing a clean EOF from a mid-frame truncation.

## Success check
Run the driver against `framing.rb`: the two-in-one-write case yields **two** parsed frames; the
one-frame-in-two-writes case yields **one** intact frame. Print each payload as it's assembled.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Two messages arrived in a single `read` and an early version returned only the first — where did the
rest go, and what does the buffer do about it? Reference what they actually observed in the driver.

**Quiz topic 2 — Design:**
Why does putting the length up front make reassembly deterministic no matter how the OS chops the
stream?

**Quiz topic 3 — Reflect:**
Say "a byte stream, not a message stream" back in your own words — what does the socket guarantee,
and what does it not?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. They can move whole messages both ways — next
those messages get *meaning* (a request/response protocol). Then point them to **Step 3** and run
`/replicant:next`.
Next: Request, response, correlation ID.
