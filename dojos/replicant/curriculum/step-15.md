---
step: 15
title: Follower catch-up
spine: workspace/catchup.rb
kind: build
reference: -
---

# Step 15 — Follower catch-up

## Frame
A follower is not always there. It crashes, or the Link partitions it, and while it's gone the leader
keeps accepting writes. When it comes back it is *behind* — missing a contiguous chunk of the log. It
must resume from exactly where it left off: not from index 0 (that re-does everything), and not by
skipping ahead (that leaves a hole). This step makes a returning follower converge again.

## Teach the mechanisms
- **Last persisted index.** Because the follower replays its own WAL on startup (you built that), it
  boots already knowing the highest index it durably holds. That number is the entire state it needs
  to advertise: "I have everything up to `N`."
- **Resume, don't restart.** On (re)connect the follower sends its last index; the leader streams
  only the entries *after* it. This is the per-follower cursor you already ship `AppendEntries` with —
  catch-up is just initializing that cursor from what the follower reports instead of assuming 0.
- **Contiguity.** The follower applies the streamed entries in order and only accepts index `N+1`
  next — never a gap. You'll verify the returned follower ends byte-for-byte equal to the leader.

## Spine  (the learner types `workspace/catchup.rb`, ~20 lines)
On connect, the follower reports its last persisted index; the leader replies with every entry after
it; the follower appends+applies them contiguously until it reaches the leader's tail. Reuse the
`AppendEntries` path and the WAL replay you already have — the new code is the handshake that seeds
the cursor from the follower's reported index and the contiguity check as it applies.

**Read first:** `docs/wire-protocol-cheatsheet.md` (add a small "here is my last index" message; the leader answers with the gap).

## Agent role
- `[explain]` Clarify how the follower knows its last index at boot (WAL replay) and why the leader
  ships the *suffix* after it. Point at the cheatsheet for the message shape.
- `[review]` Does the follower resume from its reported last index (not 0)? Does it reject a
  non-contiguous entry rather than apply it? Does the reported index come from durable state?

## Gotchas
- Restarting the follower at index 0 so it re-applies the entire log — duplicated / doubled data.
- Accepting an entry whose index leaves a gap (e.g. jumping from 4 to 7).
- Not persisting the last index, so after a restart the follower can't say where it was and silently
  refetches everything (or nothing).

## Success check
Start leader + follower; write some rows; kill the follower; write **more** rows to the leader;
restart the follower. It reconnects, catches up, and `sqlite3 follower.db .dump | sha256sum` equals
`sqlite3 leader.db .dump | sha256sum`. Confirm from the logs it resumed from its last index rather
than replaying from 1.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
A restarted follower ends up with every row counted twice. Which line in their catch-up handshake
caused it, and what value was wrong?

**Quiz topic 2 — Design:**
Why resume from the follower's reported last index instead of wiping the follower and doing a full
resync every time it reconnects?

**Quiz topic 3 — Reflect:**
How does having a single monotonic log index make catch-up cheap — what would you need instead if
entries had no order?

## Next step
There is one logical next step. Catch-up assumed you already *knew* the follower had come back — but
detecting that a node is alive or dead is the harder half. Then point them to **Step 16** and run
`/replicant:next`.

Next: Heartbeat and failure detection
