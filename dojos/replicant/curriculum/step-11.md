---
step: 11
title: The follower applies
spine: workspace/follower.rb
kind: build
reference: -
---

# Step 11 — The follower applies

## Frame
The follower's log now mirrors the leader's, but its SQLite is empty — it's storing entries without
running them. Make the follower **apply** what it receives to its own database. And while you're
here, decide the timing that makes replication practical: the leader replies to the client
**immediately** after its own commit, and replication catches the follower up in the background.

## Teach the mechanisms
- **Apply = replay, continuously.** The follower runs each newly-appended entry against its own
  SQLite, in index order, exactly once — the same "entry → `db.execute`" you already use for replay,
  now driven by arrivals.
- **Asynchronous replication.** The leader commits locally and acks the client *without waiting* for
  the follower. Replication happens after. You gain: client latency and availability don't depend on
  the follower being fast or even up. You give up: the follower is briefly behind.
- **Followers serve reads.** Once a follower is applying, it can answer `ClientRead` from its own
  database — that's the point of having one.
- **Stored ≠ applied.** Track the highest index the follower has *applied* separately from the
  highest it has *stored*. They are different numbers, and confusing them causes double-applies or
  gaps.

You'll verify by writing to the leader, reading the value back from the *follower*, and checksumming
both databases to identical once the follower catches up.

## Spine  (the learner types `workspace/follower.rb`, ~25 lines)
On the follower: after appending replicated entries, apply any not-yet-applied entries to its SQLite
in index order, advancing an `applied_index`. On the leader: make the write path ack the client right
after its local commit, independent of follower progress.

**Read first:** `docs/sqlite3-ruby-cheatsheet.md`, `docs/wire-protocol-cheatsheet.md`.

## Agent role
- `[explain]` The difference between stored and applied; why async ack is a latency/consistency
  trade; how the follower applies exactly once in order.
- `[glue]` Extend the two-node harness so the learner can write to the leader and read from the
  follower, plus a checksum helper for both DB dumps.
- `[review]` Does the follower apply each entry exactly once, in order? Is `applied_index` tracked
  separately from stored? Does the leader's client ack truly not block on the follower?

## Gotchas
- Applying an entry twice (tracking only one index for both stored and applied).
- Applying out of order when a batch arrives.
- Accidentally making the client wait for the follower ack — that's synchronous replication, not what
  this step builds.
- Reading from the follower before it has *applied* the entry (it may be stored but not yet run).

## Success check
Write a key on the leader, then read that key from the follower — after replication, the value is
there. `sqlite3 leader.db .dump | sha256sum` equals the follower's once caught up. Pause the follower
(or drop its link): the leader still replies to client writes without stalling.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
The leader replied `ok`, but an instant later a read on the follower is missing the value. Is that a
bug or expected? Have them justify the answer from how they wired the ack.

**Quiz topic 2 — Design:**
Why ack the client before the follower confirms? Make them state precisely what they gain and what
they give up by choosing async here.

**Quiz topic 3 — Reflect:**
In their own words: distinguish "the follower has the entry in its log" from "the follower has applied
it." Why does the read path care which one is true?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Because every node *re-executes* the commands,
any command whose result isn't fixed will produce different data on each node. Then point them to
**Step 12** and run `/replicant:next`.

Next: Determinism: capture and rewrite.
