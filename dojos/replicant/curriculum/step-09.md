---
step: 9
title: The single-writer queue
spine: workspace/update_queue.rb
kind: build
reference: -
---

# Step 9 — The single-writer queue

## Frame
Your server handles each client on its own thread, and every one of them wants to append to the same
log and bump the same index. Let them do it directly and they interleave records and race the
counter — two writes grab index 5, or one record's bytes land inside another's. The log corrupts. The
fix is not more locks; it's funneling every write through **one** writer.

## Teach the mechanisms
- **The Singular Update Queue.** Connection threads don't write the log themselves. They push their
  command onto a `Thread::Queue` and wait. A single dedicated **writer thread** pops commands one at a
  time and runs the durable commit path (append → fsync → apply). One writer means one order, and no
  lock is needed around the log or the index (`docs/ri-Queue.txt`, `docs/ri-Thread.txt`).
- **Handing the reply back.** Each queued item carries a way to return its result to the waiting
  connection thread — e.g. its own tiny `Thread::Queue` (or a condition variable) that the writer
  pushes the reply onto once the command has committed. The caller blocks on that until it's done.
- **Blocking, not spinning.** `Queue#pop` blocks efficiently until an item exists — no busy-wait.

You'll verify by hammering the node with concurrent writers and confirming the log comes out as a
clean, gapless, correctly-ordered sequence.

## Spine  (the learner types `workspace/update_queue.rb`, ~30 lines)
Build the serialized write path:
- a shared `Thread::Queue` of pending writes,
- a single writer thread that loops: pop a command, commit it, hand the reply back to the caller,
- an `enqueue(command)` that connection threads call — it pushes the command plus a reply channel and
  **blocks until the command has committed**, then returns the reply.

**Read first:** `docs/ri-Queue.txt`, `docs/ri-Thread.txt`, `docs/ri-Mutex.txt`.

## Agent role
- `[explain]` Why one writer removes the need for locks; how a per-request reply channel lets the
  caller block until its own write commits; the difference between blocking on a queue and spinning.
- `[glue]` A concurrency harness that fires M threads × K writes at `enqueue` and then dumps the WAL
  indexes for inspection.
- `[review]` Is there exactly one writer? Does `enqueue` block until *its* write (not just some
  write) committed? Does the writer thread survive an exception in one command, or does it die and
  wedge the node?

## Gotchas
- Letting connection threads touch the log/DB directly with no serialization — interleaved records
  and duplicate indexes.
- A busy-wait loop instead of blocking on `Queue#pop`.
- The writer thread raising and dying silently — every future write hangs forever.
- Returning to the caller before the write actually committed.

## Success check
Fire many concurrent clients writing at once (the harness). Dump the WAL: the indexes are a strictly
increasing `1..N` with **no gaps and no duplicates**, records are whole (never interleaved), and the
row count equals the total number of requests.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Two threads call their append at the same instant with no queue in front. Walk through exactly what
corrupts — in the file bytes and in the index counter.

**Quiz topic 2 — Design:**
Why is a single writer thread both *simpler* and *safer* than putting a mutex around every append?
Push them past "it avoids races" to what the single writer gives them structurally.

**Quiz topic 3 — Reflect:**
Serializing writes hands them a total order "for free." In their own words, what does that mean and
why will an ordered, single-writer log matter for copying it elsewhere?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. The node now has a clean, ordered, durable log
of commands — everything you need to start copying it to another machine. Then point them to
**Step 10** and run `/replicant:next`.

Next: Ship entries to a follower.
