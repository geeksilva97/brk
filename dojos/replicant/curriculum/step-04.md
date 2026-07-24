---
step: 4
title: Peer links and the fault injector
spine: workspace/link.rb
kind: build
reference: -
---

# Step 4 — Peer links and the fault injector

## Frame
Nodes have to talk to **each other**, not just to clients — and to learn distributed *failure* you
have to be able to *cause* it on command. Build a **Link**: a long-lived node-to-node connection you
can tell to drop, delay, reorder, or partition messages by flipping a setting. This is the single
most important thing you build early: every failure you study later becomes a knob you turn, not a
race you hope to catch in the wild.

## Teach the mechanisms
- **A persistent socket per peer** — one `TCPSocket` held open to each peer (a "single socket
  channel") preserves per-peer order. `docs/tcp-sockets-cheatsheet.md`.
- **Fault settings** — the Link's `send`/`deliver` consult mutable knobs: `drop` (probability),
  `delay` (ms), `partition` (on/off, drop everything), and optionally `reorder` (buffer + shuffle).
- **Why inject faults in software?** You can reproduce a partition or 50% loss *deterministically*,
  in a test, in seconds — instead of unplugging cables and hoping.

## Spine  (the learner types `workspace/link.rb`, ~30 lines)
A `Link` class wrapping a peer socket. `send(msg)` and `deliver` apply the current fault settings
before/at transmission: honor `partition` (drop all), a `drop` probability, a `delay`, and expose the
knobs so a test can flip them at runtime. Frame messages with the Step-2 framing over the socket.

**Read first:** `docs/tcp-sockets-cheatsheet.md`.

## Agent role
- `[explain]` How a per-peer persistent socket differs from reconnecting each message, and why
  ordering matters.
- `[glue]` A two-node harness that stands up two Links and passes messages, plus setters to flip the
  knobs — the fault *logic* inside the Link is the learner's.
- `[scaffold]` (none.)
- `[review]` Do faults apply symmetrically (both directions) where intended? Does `delay` delay *one
  message* rather than freezing the whole node? Is the Link reusable across peers?

## Gotchas
- Applying a fault in only one direction when you meant both.
- A `delay` implemented as a blocking `sleep` on the node's main path — freezes everything.
- Reorder with no buffer to hold the reordered messages.
- A Link so hard-coded to two nodes you can't reuse it.

## Success check
With the two-node harness: `partition=true` → messages stop arriving; `partition=false` → delivery
resumes. `drop=1.0` → nothing arrives; `drop=0.5` → roughly half. `delay=500` → messages land visibly
late. Watch each knob change the observed delivery.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
With `drop=0.5`, half the messages vanish. How would you tell a genuine injected drop from a bug in
your own send path? Reference what they watched.

**Quiz topic 2 — Design:**
Why build fault injection *into* the link instead of testing failure by killing processes or pulling
network?

**Quiz topic 3 — Reflect:**
Why does having a controllable link matter for the reliability behaviors you'll build on top of it?
(Answer about controllability itself — don't name specific later mechanisms.)

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Now that the link can drop replies, a client
that retries will double-apply a write unless the node defends against it. Then point them to
**Step 5** and run `/replicant:next`.
Next: Idempotent receiver.
