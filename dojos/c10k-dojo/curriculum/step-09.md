---
step: 9
title: Puma-like thread pool
chapter: 10
session: 2
spine: workspace/puma_like.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 9 — Building a Puma-like server

## Frame
Unbounded threads die on stack memory. The fix is the reactor + pool pattern Puma uses: one acceptor
thread pushes connections onto a bounded queue; a fixed pool of worker threads pops and serves them.
Bounded concurrency = predictable memory + backpressure.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** Why a *bounded* queue between the acceptor and the worker pool, not an unbounded one?

A good answer covers: backpressure — an unbounded queue under overload grows until OOM; a bounded
queue makes the acceptor block/refuse, shedding load instead of crashing. It's not about simplicity;
it's about survival under overload. It does matter at these sizes — the moment held connections
exceed the pool, an unbounded queue grows without bound.

## Spine  (`workspace/puma_like.rb`, ~18 lines)
One acceptor thread: `loop { queue << server.accept }` (bounded `Thread::Queue` / `SizedQueue`).
A pool: `POOL.times { Thread.new { loop { serve(queue.pop) } } }`. Reuse `build_env`.

**Read first:** `docs/ri-dump/Queue.txt`, `docs/ri-dump/Thread.txt`, `docs/ri-dump/Mutex.txt`.

## Agent role
- `[explain]` The reactor/pool shape; SizedQueue backpressure.
- `[review]` Bounded queue? Fixed pool size (hardcoded, not `nprocessors`)? Workers loop forever?

## Gotchas
- Unbounded queue → memory blowup under the holder.
- Pool too small → latency cliff; too large → stack memory.
- Sharing a non-thread-safe object across workers (sets up Step 10).

## Success check
`/c10k-dojo:bench` (Silver): throughput is great, but **Silver fails** — measured ceiling
**~5,140 held** (= 16 workers + 1024 queue + ~4096 kernel backlog; the rest time out). The point for
the learner: **more RAM won't move this** — it's a *structural* cap, not memory. `/io` p99 ≈ 720 ms
(better than single-thread's ~10 s, because 16 workers overlap the I/O waits — the GVL releases during
sleep). A thread-*per*-connection variant fails differently: OOM on stacks in the low thousands.
*Footnote:* real Puma cheats here — an NIO "reactor" buffers slow clients off the pool, so it holds
more than this naive teaching pool. (Numbers: `reference/DRY-RUN-FINDINGS.md`.)

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** The pool shares one Rack app across worker threads. What can go wrong if the app
mutates shared state?

A good answer covers: a data race — interleaved read-modify-write corrupts the state. The GVL doesn't
make it safe; it can switch threads mid-operation, and `+=` isn't atomic. The pool doesn't serialize
everything; workers run concurrently across requests.
**Next:** Step 10 — when threads bite (races + `Mutex`). `/c10k-dojo:next`.
