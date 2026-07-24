---
step: 8
title: Replay on startup
spine: workspace/replay.rb
kind: build
reference: -
---

# Step 8 — Replay on startup

## Frame
You now log durably before applying — but a node that just crashed comes back with a log full of
history and a database that may be stale or empty. Durability only pays off if the node can
**recover**: rebuild its SQLite state from the log on startup. This is where "the log is the source
of truth, the database is derived" stops being a slogan and becomes code.

## Teach the mechanisms
- **Rebuild from the log, in order.** On boot, start from an empty database, read the WAL in index
  order, and re-apply each command. The resulting SQLite state is a pure function of the log.
- **The database is a cache of the log.** You never trust the old `.db` file to be correct after a
  crash; you regenerate it. That's why the log had to be durable first.
- **Idempotent schema.** Use `CREATE TABLE IF NOT EXISTS` so replay works against a fresh DB without
  blowing up on the first command.
- **A torn tail is expected.** The crash may have left a half-written final record. Define recovery
  as: apply every record you can read *completely*, and stop at the first one you can't.

You'll verify by killing the node mid-run and watching it come back with exactly the state the log
implies.

## Spine  (the learner types `workspace/replay.rb`, ~20 lines)
Write `replay(wal, db)`: iterate the WAL entries in index order and apply each command to the
database. Call it at node startup, against a freshly-opened (empty) SQLite, *before* the node begins
serving requests.

**Read first:** `docs/sqlite3-ruby-cheatsheet.md`.

## Agent role
- `[explain]` Why replay must run against an empty DB; why index order matters; what "derived state"
  means.
- `[glue]` A launcher that wipes the derived `.db`, runs `replay`, then starts serving — so the
  success check is one command.
- `[review]` Is replay ordered by index? Does it run before serving? Does it handle a truncated final
  record by stopping rather than crashing? Is it safe to run twice (no double-apply against a
  non-empty DB)?

## Gotchas
- Replaying on top of an existing populated DB — every command applies twice.
- Applying out of index order — the derived state no longer matches history.
- Relying on the leftover `.db` file instead of the log — the whole point is that the file may be
  wrong after a crash.
- Crashing on the half-written last record instead of stopping cleanly at it.

## Success check
Write several rows, then `kill -9` the node mid-run. Restart it. Checksum the rebuilt database's dump
(`sqlite3 node.db .dump | sha256sum`) against what the log implies — they match, with no torn or
partial rows. Run the node twice in a row and confirm the state doesn't double.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
The crash truncated their last log record. Walk them through what `replay` should do with it and why
stopping (rather than applying a partial command) is the safe choice.

**Quiz topic 2 — Design:**
Why treat the log as source-of-truth and SQLite as a throwaway cache? What does that buy them over
just trusting the database file?

**Quiz topic 3 — Reflect:**
Which property of the append-only log (from the previous step) is what makes replay *deterministic* —
same log in, same state out, every time?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. One connection appending at a time is fine —
but real clients arrive concurrently, and concurrent appends race the log and the index. Then point
them to **Step 9** and run `/replicant:next`.

Next: The single-writer queue.
