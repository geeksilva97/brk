---
step: 12
title: "Determinism: capture and rewrite"
spine: workspace/rewrite.rb
kind: build
reference: -
---

# Step 12 — Determinism: capture and rewrite

## Frame
Replication here works by each node *re-executing* the command. That's fine for `INSERT … VALUES
('ada')` — but `INSERT … VALUES (RANDOM())` or `… CURRENT_TIMESTAMP` computes a **different value on
each node**, and your replicas silently diverge. You'll reproduce that divergence, then fix it the way
command-replication systems do: pin the nondeterministic value once, at the leader, before it enters
the log.

## Teach the mechanisms
- **Why re-execution + nondeterminism = divergence.** `RANDOM()` rolls a fresh number on the leader
  and again on the follower; `CURRENT_TIMESTAMP` reads each machine's clock. Same SQL text, different
  results, different databases.
- **The fix: capture-and-rewrite at the leader.** Before `wal.append`, the leader rewrites the
  command into a deterministic one — evaluate the nondeterministic piece *now* and substitute a
  literal: `RANDOM()` → a concrete integer, `CURRENT_TIMESTAMP`/`'now'` → a captured timestamp
  literal. Every node then logs and applies *identical, deterministic* SQL. (This is exactly what
  rqlite does with its statement rewriting.)
- **Once, at the source.** The rewrite happens a single time, on the leader, *before* the command is
  logged — so the value is baked into the one true entry that everyone replays.

You'll verify by first *seeing the bug* (divergent checksums), then enabling the rewrite and watching
the checksums become identical.

## Spine  (the learner types `workspace/rewrite.rb`, ~25 lines)
Write a `rewrite(sql, params)` that detects the common nondeterministic constructs and returns a
deterministic command with concrete literals substituted. Insert it into the leader's write path
**before** `wal.append`, so only the rewritten command is ever logged.

**Read first:** `docs/sqlite3-ruby-cheatsheet.md`.

## Agent role
- `[explain]` Which SQL constructs are nondeterministic and why; why the rewrite must be at the
  leader before logging, not at apply time; what "deterministic command" means for replication.
- `[glue]` A demo harness with two modes — rewrite off (to show divergence) and on — that inserts a
  `RANDOM()` row and prints both nodes' checksums.
- `[review]` Does the rewrite happen once, at the leader, before append? Is the *rewritten* SQL what
  gets logged (not the raw statement)? Does it leave already-deterministic SQL untouched?

## Gotchas
- Rewriting on the follower too — it must happen once, at the leader, or you're back to two values.
- Logging the raw statement and rewriting at apply time — too late; the nondeterminism is re-rolled
  per node.
- Missing a nondeterministic function (only handling `RANDOM()` but not the timestamp, say).
- Assuming rowid/autoincrement is automatically safe under concurrent writers — flag it as a sharp
  edge, even if you don't fully solve it here.

## Success check
First, with rewrite **off**: insert a row using `RANDOM()`, let it replicate, and dump both
databases — `sha256sum` differs. Turn rewrite **on**, repeat: after replication the two dumps
`sha256sum` **identical**.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Leader and follower dumps differ in exactly one column. Trace how `RANDOM()` produced that, step by
step, in the un-rewritten path.

**Quiz topic 2 — Design:**
Why capture-and-rewrite at the leader *before* the log, rather than rewriting when each node applies?
Push on the timing.

**Quiz topic 3 — Reflect:**
In their own words: what property must a command have to be safely replicated by re-execution — and
how does the rewrite give it that property?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Async replication means the follower's applied
state trails the leader's — so a client can write, read a follower, and miss its own write. Then point
them to **Step 13** and run `/replicant:next`.

Next: The high-water mark read gate.
