---
step: 17
title: The generation clock
spine: workspace/generation.rb
kind: build
reference: -
---

# Step 17 — The generation clock

## Frame
Failure detection is a guess, so it will sometimes be wrong: a leader that was only paused or
partitioned gets declared dead, the cluster moves on — and then the old leader wakes up still
believing it's in charge and keeps writing entries. Those stale writes corrupt the log. The fix is to
number leadership eras: stamp every entry with a **generation**, and reject anything carrying an
older one.

## Teach the mechanisms
- **Generation (term).** A monotonically increasing integer, bumped every time leadership changes.
  It is durable state, persisted like the log, so it survives a restart.
- **Stamp every entry.** Each new entry records the generation under which it was created. A node
  tracks the highest generation it has seen and **rejects** any `AppendEntries`/write whose
  generation is *lower* than that. A revived old leader is, by definition, on an old generation — so
  its writes bounce.
- **Additive change to the WAL record — call it out as you build.** Your record was
  `{index, sql, params}`; it becomes `{index, generation, sql, params}`. Replay must tolerate old
  records that predate the field: default a missing `generation` to `0`. Make this the explicit first
  move of the spine so you don't silently break replay.

## Spine  (the learner types `workspace/generation.rb`, ~25 lines)
Add the `generation` field to the WAL record (defaulting to `0` on replay of older records); hold
`current_generation` as persisted node state; reject any incoming message whose generation is below
the highest seen; and bump the generation on a leadership change (trigger it by hand here to simulate
one). Reuse your existing append/replay and `AppendEntries` receive path.

**Read first:** `docs/wire-protocol-cheatsheet.md` (carry `generation` on the messages that mutate state).

## Agent role
- `[explain]` Clarify why the comparison is "reject lower than the highest seen," and why the number
  must be persisted. Point at how the record grows by one field.
- `[review]` Is the generation persisted (not reset on restart)? Is the comparison the right
  direction (reject *older*)? Is *every* new entry stamped? Does replay default the field on
  pre-generation records so old logs still load?

## Gotchas
- Not persisting the generation, so it resets to 0 on restart and the old-leader defence evaporates.
- Comparing the wrong way (accepting older, rejecting newer).
- Stamping only some entries, leaving unstamped ones that can't be ordered against a leadership change.
- Forgetting to default `generation` when replaying records written before this step — replay crashes
  or mis-orders.

## Success check
Run a small cluster. Partition the current leader away. On the other side, bump the generation (a new
era). Bring the old leader back and have it try to write with its stale generation: the write is
**rejected**. After it rejoins, the databases show no divergence — the stale writes never landed.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
The revived old leader's write gets rejected. Walk the exact generation comparison in their code that
does the rejecting, using the two generation numbers from their run.

**Quiz topic 2 — Design:**
Why order leadership eras with a monotonic integer instead of a wall-clock timestamp on each entry?

**Quiz topic 3 — Reflect:**
"Split-brain in time" — describe it in your own words, and how a single number on every entry closes
that window.

## Next step
There is one logical next step. You've made a stale leader harmless — but so far *you* have been
appointing leaders by hand. Nodes need to choose one themselves when the current leader dies. Then
point them to **Step 18** and run `/replicant:next`.

Next: Naive election and split-brain
