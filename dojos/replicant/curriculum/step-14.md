---
step: 14
title: Monotonic and consistent-prefix reads
spine: workspace/sticky.rb
kind: build
reference: -
---

# Step 14 — Monotonic and consistent-prefix reads

## Frame
The read gate stops a client from missing its *own* write. But a client that spreads its reads across
two followers at different lag can still see **time run backward** — a value it already saw
disappears on the next read from a laggier replica. That's a monotonic-reads violation, and its
cousin, consistent-prefix, is writes appearing out of causal order. Pin the client down and the common
case goes away.

## Teach the mechanisms
- **Monotonic reads.** A single client must never see the clock go backward. Enforce it by making a
  client **stick to one replica** for its session, and/or by refusing any read result whose applied
  index is *lower* than the highest the client has already observed.
- **Consistent-prefix.** Because each node applies entries strictly in index order, a follower never
  exposes a later write without the earlier ones — no gaps in the middle are ever visible. Apply-in-
  order is what buys this; make sure your follower never applies out of sequence.
- **Per-session, not global.** The watermark that enforces monotonicity belongs to the *client
  session*, not to the cluster. No global coordination is needed — just memory on the client side.

You'll verify by running two followers at different lag and confirming a client's repeated reads never
go backward.

## Spine  (the learner types `workspace/sticky.rb`, ~25 lines)
Client-side session logic: remember the chosen follower and the highest applied index the client has
observed; when a read comes back from a node whose applied index is *below* that high-water mark,
reject it and retry (a stickier node, or the same one once caught up). Keep applies in index order on
the follower so no prefix gap shows.

**Read first:** `docs/wire-protocol-cheatsheet.md`, `docs/sqlite3-ruby-cheatsheet.md`.

## Agent role
- `[explain]` The difference between monotonic reads (per client, no going backward) and read-your-
  writes (your own last write); why apply-in-order gives consistent-prefix for free.
- `[glue]` A harness with two followers at different injected lag and a client loop doing repeated
  reads, logging the applied index each read saw.
- `[review]` Is the observed-watermark tracked *per client session*, not globally? Does the client
  actually reject a lower-index result rather than accept it? Does the follower apply strictly in
  order?

## Gotchas
- Load-balancing every read to a random follower — reintroduces backward time immediately.
- Tracking the high-water mark globally instead of per client session.
- Confusing monotonic reads (a per-client guarantee) with read-your-writes (Step 13's gate) — they
  solve different anomalies.
- Applying entries out of order on the follower, breaking the consistent prefix.

## Success check
Two followers at different injected lag; a client does many repeated reads. Across all of them, the
client never observes a value older than one it already saw — the applied index the client sees is
non-decreasing, run after run.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Round-robining reads across two followers makes a counter appear to *decrease*. Which anomaly is that,
and what in their unpinned client caused it?

**Quiz topic 2 — Design:**
Why does per-client stickiness fix monotonic reads without any global coordination? What would a
global fix cost that this one doesn't?

**Quiz topic 3 — Reflect:**
They've now seen three anomalies — read-your-writes, monotonic reads, consistent-prefix. Have them
give a one-sentence distinction between the three in their own words.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. So far nodes only ever crash politely — next you
make a follower that was *down* rejoin and catch up from exactly where it left off. Then point them to
**Step 15** and run `/replicant:next`.

Next: Follower catch-up.
