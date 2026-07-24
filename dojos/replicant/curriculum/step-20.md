---
step: 20
title: Quorum commit
spine: workspace/commit.rb
kind: build
reference: -
---

# Step 20 — Quorum commit

## Frame
Election now picks one leader safely. The last piece is committing *writes* safely. Right now a
leader acks a client the moment it appends locally — so a leader stranded in a minority partition
would happily confirm a write that a majority never saw, and that write can be lost when the majority
side moves on. The fix: a write is committed only once a majority holds it, and the client's reply
waits for that. This is the capstone — when it works, you have hand-built a single-leader replicated
log that is, in its essentials, Raft.

## Teach the mechanisms
- **Match index per follower.** The leader already ships `AppendEntries`; now it records, per
  follower, the highest index that follower has acknowledged (its *match index*).
- **Quorum commit / the committed high-water mark.** The leader computes the highest index that a
  **majority** of nodes (itself included) hold, and advances the committed high-water mark to it.
  Below that mark is durable-against-one-failure; above it is tentative.
- **Request Waiting List.** A client write doesn't reply on local append. It **parks**, keyed by its
  entry's index, until the committed high-water mark reaches that index — then it replies success.
- **Why a minority leader refuses.** A leader that can't reach a majority can never advance the
  committed mark past the new entry, so the parked client is never satisfied: the write times
  out / is refused, and is *never* falsely acked. Reuse the high-water mark, the quorum, and the
  waiting list.

## Spine  (the learner types `workspace/commit.rb`, ~30 lines)
On the leader: track each follower's match index; compute the majority-committed index and advance the
committed high-water mark to it; park each client write in a waiting list keyed by its index and reply
only when the committed mark passes it (refuse/time out if it never does). Remember the leader counts
toward its own majority.

**Read first:** `docs/wire-protocol-cheatsheet.md` (the ack carries the follower's match index).

## Agent role
- `[explain]` Clarify the difference between "appended locally" and "committed by a majority," and how
  the waiting list bridges the async replication path back to a synchronous client reply. Point at how
  the committed index is computed from the set of match indices.
- `[review]` Does the client reply wait for majority-commit, not local append? Is the committed mark
  advanced only on a genuine majority (leader counted)? Are waiting-list entries cleaned up on
  timeout? Does a minority leader correctly fail to commit?

## Gotchas
- Acking the client on local append (before a majority) — the exact bug this step exists to kill.
- Advancing the committed high-water mark on a minority of acks.
- Leaking waiting-list entries when a write times out (unbounded growth / stuck clients).
- Forgetting the leader itself counts toward the majority when computing the committed index.

## Success check
Run 3 nodes. Kill the leader: the majority side elects a new leader (Step 19) and keeps committing. A
client attached to a stranded **minority** leader is **refused** — its write blocks and times out,
never a false success. Verify that every write that was ever acked as committed is present on the new
leader: no committed write is lost.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Imagine your minority leader had acked a client on local append. Walk the sequence where that acked
write then vanishes — which invariant did the early ack break?

**Quiz topic 2 — Design:**
Why block the client until majority-commit instead of replying success on local append and cleaning up
later?

**Quiz topic 3 — Reflect:**
Trace the whole chain you built — append to the log, replicate to followers, commit on a quorum, and
only then serve it as safe. In your own words, how does that chain keep a replicated log consistent
even as leaders come and go?

## Next step
That's the ramp. You started with a single socket and finished with a leader-elected, quorum-committed
replicated log on top of SQLite — the safety core of a Raft-like distributed database, built by hand,
one primitive at a time. Run `/replicant:status` to see the full path you completed.

When you're ready for more, the next phase is **sharding** — splitting the data itself across many
nodes so the system holds more than one machine can — a separate journey that builds on everything
here.
