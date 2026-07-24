---
step: 10
title: Ship entries to a follower
spine: workspace/replicator.rb
kind: build
reference: -
---

# Step 10 — Ship entries to a follower

## Frame
A single node's log is durable but alone — lose the machine and you lose everything. The first move
toward surviving that is to copy the log to a second node, so a **follower**'s log mirrors the
**leader**'s, entry for entry. You already have the pieces: an ordered log and a link between nodes.

## Teach the mechanisms
- **Per-follower cursor.** The leader remembers, for each follower, the next index that follower
  still needs. Followers lag, disconnect, and reconnect at different points — so the leader tracks
  each one's position independently.
- **`AppendEntries`.** A message (leader → follower) carrying the log entries *after* the follower's
  cursor. The follower appends them to its own WAL and **acks** the highest index it now has. On the
  ack, the leader advances that follower's cursor.
- **Ship over the link.** Send `AppendEntries` through the fault-injectable link. The link can drop a
  message — that's fine: a missed ack just means the leader resends from the same cursor next round.
  Self-healing falls out of the cursor.
- **Entries, not rows.** You ship *log entries* (the commands), never the follower's applied rows or
  the `.db` file. The follower re-derives its own state from the entries.

You'll verify by writing to the leader and watching the follower's *log* grow to match — driven only
by messages over the link.

## Given, not derived
The **link** (Step 4) and the **WAL** (Step 6) are yours from earlier and are used here as-is. The
lesson of this step is the *ship-past-the-cursor loop* and the cursor bookkeeping — not those
components.

## Spine  (the learner types `workspace/replicator.rb`, ~30 lines)
Two halves:
- **Leader side:** `replicate_to(follower)` — send the entries with index greater than that
  follower's cursor as an `AppendEntries`; on receiving the ack, advance the cursor to the acked
  index.
- **Follower side:** an `AppendEntries` handler — append the received entries to its own WAL (in
  order) and reply with an ack for the highest index it holds.

**Read first:** `docs/wire-protocol-cheatsheet.md`, `docs/pack-unpack-cheatsheet.md`.

## Agent role
- `[explain]` What a cursor is and why it's per-follower; why a dropped message is harmless given the
  cursor; the difference between shipping entries and shipping applied state.
- `[glue]` A two-node harness (start a leader + a follower, wire a link between them) so the learner
  can drive writes and inspect both logs.
- `[review]` Does the leader resend only entries past the cursor (not from 0)? Does it advance the
  cursor *after* the ack, not before? Does it ship entries rather than rows?

## Gotchas
- Resending the whole log from index 0 every round — ignores the cursor, wastes the link, and risks
  double-appends on the follower.
- Advancing the cursor before the ack arrives — a dropped message now means a silent gap.
- Assuming the link is lossless/ordered — it isn't; design for resend.
- Shipping applied rows or the database file instead of log entries.

## Success check
Two nodes, a link between them. Write 5 commands to the leader. The follower's WAL ends up with the
same 5 entries, same order, same indexes — and it got there purely via `AppendEntries` over the link,
not by touching the leader's files.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
The link drops one `AppendEntries`. Trace how the cursor makes the *next* round repair the gap with
no special-case code.

**Quiz topic 2 — Design:**
Why ship log entries rather than the follower's applied rows, or the leader's `.db` file? What would
break with the alternatives?

**Quiz topic 3 — Reflect:**
"The follower's log mirrors the leader's." In their own words, what does that guarantee right now —
and what does it *not* guarantee yet about the follower's database?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. The follower is hoarding entries it hasn't run
— its database is still empty. Then point them to **Step 11** and run `/replicant:next`.

Next: The follower applies.
