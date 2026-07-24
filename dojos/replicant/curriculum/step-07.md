---
step: 7
title: fsync before apply
spine: workspace/apply.rb
kind: build
reference: -
---

# Step 7 — fsync before apply

## Frame
Appending to the log isn't the same as *durably* appending. A crash can strike after SQLite has the
data but before the log record is safely on disk — leaving your database ahead of its own history,
which is unrecoverable. The rule that prevents it is in the name "write-ahead": get the log record
onto the disk **first**, then apply the command to SQLite.

## Teach the mechanisms
- **The OS buffers your writes.** A `write` to the log file usually lands in the OS page cache, not
  the platter. If the machine dies, that buffered record is gone. `IO#fsync` forces the bytes all the
  way to disk and only returns once they're durable (`docs/ri-IO.txt`).
- **The ordering rule: log → fsync → apply.** For every write: `append` the record, `fsync` the log
  file, and only *then* `db.execute(sql, params)` against SQLite. The log is always at least as
  current as the database, never behind it.
- **Apply = run the command.** Applying a log entry is just executing its SQL with its params
  (`docs/sqlite3-ruby-cheatsheet.md`).

You'll verify by writing N commands and confirming the log record count equals the rows applied, and
by watching "appended" always print before "applied".

## Spine  (the learner types `workspace/apply.rb`, ~20 lines)
Write the durable write path: a `commit(command)` that calls `wal.append`, then `fsync` on the log's
IO handle, then applies the command to SQLite. Route the node's writes through `commit` so nothing
reaches SQLite without first being durably logged.

**Read first:** `docs/sqlite3-ruby-cheatsheet.md`, `docs/ri-IO.txt`.

## Agent role
- `[explain]` What fsync actually guarantees vs a bare `write`; why "log-then-apply" is the safe
  order and "apply-then-log" is not.
- `[glue]` A small harness that runs `commit` in a loop and prints an append/apply trace line, if
  useful for the success check.
- `[review]` Is fsync called *between* append and apply, every commit? Is the apply strictly after?
  Is an apply error handled sanely (the record is already durable — the node shouldn't silently
  pretend the write didn't happen)?

## Gotchas
- Applying to SQLite before fsync — a crash leaves the DB holding a write the log never durably
  recorded.
- Never calling fsync at all — "durable" becomes a hope, not a fact.
- Fsyncing once at the very end of a batch instead of per commit — everything since the last fsync is
  at risk.
- Swallowing an apply error after the log already recorded the command, so log and DB silently drift.

## Success check
Run N writes through `commit`. The WAL record count equals the number of rows in SQLite. Your trace
shows, for every write, `appended index=k` strictly before `applied index=k`. (If you're bold: add a
deliberate `exit!` between fsync and apply, restart, and confirm the log has the record even though
SQLite didn't get it — the log is ahead, which is the recoverable direction.)

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
A crash lands between two of their operations. Which surviving state is recoverable — log ahead of
DB, or DB ahead of log — and exactly why does their ordering guarantee the recoverable one?

**Quiz topic 2 — Design:**
Why fsync on *every* commit rather than batching many commits per fsync? Have them name what they'd
gain and what they'd risk with each choice.

**Quiz topic 3 — Reflect:**
"Write-ahead" — now that they've ordered the two writes, what does the phrase actually mean in their
own code?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Durability is worthless without recovery —
a restarted node has to turn its log back into state. Then point them to **Step 8** and run
`/replicant:next`.

Next: Replay on startup.
