---
step: 6
title: The append-only log
spine: workspace/wal.rb
kind: build
reference: -
---

# Step 6 — The append-only log

## Frame
Your node applies each write straight to SQLite. That's fine until the process dies mid-write — the
data is gone, and worse, there is no ordered *history* of what happened, so there is nothing to hand
to another machine. A **write-ahead log** fixes both at once: an append-only file where every write
is recorded, in order, as a command — before anything else happens to it.

## Teach the mechanisms
- **Append-only.** The log is opened in append mode (`"ab"`) and *never* rewritten. History is
  immutable; you only ever add to the end. That is what makes it replayable and, later, shippable.
- **A record is a command, not a row.** Each entry is a Hash like
  `{ "index" => 1, "sql" => "INSERT …", "params" => [...] }`. You are logging the
  *intent* (the SQL command), not SQLite's storage. Re-running the commands reproduces the state.
- **A monotonically increasing index.** Every entry gets the next integer. The index is what turns a
  pile of writes into an *ordered* log — it's the address of an entry and the currency of everything
  built on top.
- **Framing on disk = framing on the wire.** Reuse the exact 4-byte big-endian length prefix from
  the transport (`docs/pack-unpack-cheatsheet.md`) to delimit records in the file, so reading the log
  back is the same length-then-payload discipline you already know.

You'll verify by appending a few commands and reading them straight back in order, and by watching the
file grow and never shrink.

## Spine  (the learner types `workspace/wal.rb`, ~25 lines)
Write a `WAL` class over one file:
- `append(command) -> index` — assign the next index, serialize the record
  (JSON is fine), and write it length-prefixed to the end of the file. Return the index.
- `read_all` (or `each`) — reopen the file, walk it record by record using the length prefix, and
  yield/return the decoded entries **in index order**.
- The **next index must be derived from what's already on disk** (count/last entry), not from a
  counter that only lives in memory — a restarted node has to continue the sequence, not restart it.

**Read first:** `docs/pack-unpack-cheatsheet.md`, `docs/sqlite3-ruby-cheatsheet.md`.

## Agent role
- `[explain]` How append mode differs from truncate mode; why the length-prefix reader from the
  transport applies unchanged to a file; what "monotonically increasing" buys you.
- `[glue]` A tiny driver script that appends three sample commands and prints `read_all`, if the
  learner wants a harness to see the output.
- `[review]` Is the file opened append-only (not truncating)? Is the index derived from disk? Is
  `bytesize` (not `length`) used for the prefix?

## Gotchas
- Opening the file in `"wb"`/truncate mode — you wipe the whole log on every boot.
- Keeping the index only in memory — a restart resets it to 1 and you corrupt the sequence.
- Not flushing after append, so a subsequent `read_all` misses the last record.
- Using `String#length` (characters) instead of `bytesize` (bytes) for the frame length.

## Success check
Append three commands, then `read_all`: you get the same three back, in order, with indexes `1, 2, 3`.
`ls -l` the log file before and after another append — it only ever
grows. `xxd` the file to see each record is a 4-byte length followed by that many bytes of JSON.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Replaying the file reproduces the exact same SQLite state every time. What property of *how they
recorded each entry* makes that true — and what would break it?

**Quiz topic 2 — Design:**
Why append-only? Push on why they don't just update the log in place or keep the latest value —
what does an immutable, ordered history give them that a mutable one can't?

**Quiz topic 3 — Reflect:**
In their own words: what does the *index* add that a plain list of writes doesn't? Why is "order" the
load-bearing idea here?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. The log exists, but nothing guarantees a record
actually reaches the disk before its effect does. Then point them to **Step 7** and run
`/replicant:next`.

Next: fsync before apply.
