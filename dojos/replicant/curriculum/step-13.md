---
step: 13
title: The high-water mark read gate
spine: workspace/hwm.rb
kind: build
reference: -
---

# Step 13 — The high-water mark read gate

## Frame
Asynchronous replication has a cost you can now feel: a follower's applied state trails the leader.
So a client that writes a value and immediately reads it from a follower can get the *old* value
back — it read its own write out of existence. Fix it by giving each node a notion of "how far I've
applied" and letting a read demand a node that's caught up to the write it cares about.

## Teach the mechanisms
- **Two frontiers per node.** The **log tail** is the highest index a node has *stored*; the
  **high-water mark** is the highest index it has *applied* and can safely serve. They are different
  numbers, and reads must respect the second one.
- **The applied index is a logical clock.** A write returns the index it was assigned. A client that
  remembers "my write got index N" can then ask any node: "only answer if your applied index ≥ N."
- **The read gate.** A `ClientRead` carries a `min_index`. A node serves it only if its high-water
  mark ≥ `min_index`; otherwise it says "not caught up" and the client retries elsewhere (or waits).
- **Why this is enough for read-your-writes.** The client's own last write index is the only
  watermark it needs to never see staleness of its own data. (This is the mechanism behind Turso /
  libSQL embedded-replica read-your-writes.)

You'll verify by injecting replication lag and confirming a gated read always sees the client's own
just-written value.

## Spine  (the learner types `workspace/hwm.rb`, ~25 lines)
- Expose each node's high-water mark (its `applied_index`).
- Make a write reply include the index it was assigned.
- Make a `ClientRead` carry a `min_index`, and have the node serve only when its high-water mark has
  reached it (else signal "not yet" so the client can retry a caught-up node).

**Read first:** `docs/wire-protocol-cheatsheet.md`, `docs/sqlite3-ruby-cheatsheet.md`.

## Agent role
- `[explain]` The tail-vs-applied distinction; why the applied index is the correct read frontier;
  how the client uses its own write index as the watermark.
- `[glue]` A harness that sets a fixed replication delay on the link and scripts a write-then-read so
  the anomaly is reproducible.
- `[review]` Is the gate comparing against the *applied* index, not the stored tail? Does the write
  actually return its assigned index? Does the node refuse (not silently serve stale) when behind?

## Gotchas
- Gating on the stored/tail index instead of the applied high-water mark — you'll serve entries that
  aren't applied yet.
- The leader forgetting to return the assigned index, so the client has no watermark to gate on.
- Comparing indexes that come from *different* logs as if they were the same scale.
- Serving the read anyway when behind, defeating the whole gate.

## Success check
Inject ~500 ms of replication lag on the link. A client writes (gets index N), then issues a read
with `min_index = N`. It *always* sees its own write — never the stale value — even though the
follower is visibly behind for a while.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
With lag and no gate, why *exactly* does the follower hand back the old value right after a successful
write? Have them trace it through their applied index.

**Quiz topic 2 — Design:**
Why is the *applied* high-water mark the right read frontier, and not the stored tail? What goes wrong
if they pick the tail?

**Quiz topic 3 — Reflect:**
Explain the "two frontiers" — tail vs high-water mark — in their own words, and why a reader must care
about the second one.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. The gate fixes reading your *own* writes — but a
client bouncing between followers at different lag can still watch time run backward. Then point them
to **Step 14** and run `/replicant:next`.

Next: Monotonic and consistent-prefix reads.
