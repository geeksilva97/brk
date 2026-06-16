---
step: 3
title: Why one server isn't enough
chapter: 3
session: 0
spine: "-"
kind: bench
reference: rack_based_servers/server.rb
---

# Step 3 — Why one server isn't enough (meet the benchmark)

## Frame
No new code this step. We make the single-threaded server's limitation *measurable* — and meet the
harness that will grade every server you build from here on. You're going to try to clear the Bronze
tier (1,000 concurrent held connections) with the Step-2 server, and watch it fail.

## Diagnose-quiz  (AskUserQuestion)
**Question:** Before we run it — what do you predict happens when 1,000 clients connect at once to the
single-threaded Rack server and each holds its connection open?
- ✅ "It serves the first, and the other 999 queue/stall — most time out." Confirm; this is the cost
  of one-at-a-time.
- ❌ "It handles them, just slowly." → Only true if each request is instant; held connections pin the
  one process entirely.
- ❌ "It crashes / OOMs." → Not yet — a single process holding sockets is cheap on memory; the failure
  here is *throughput/latency*, not memory. (Memory failure is Step 4's lesson.)

## The run  (no spine; drive the harness)
1. Confirm `/c10k-dojo:setup` has built the docs bundle + the `c10k-target` image.
2. Run `/c10k-dojo:bench` (→ `env/bench/run.sh workspace/rack_server.rb bronze http`).
3. Read the result **with the learner — and look past the verdict.** The single-threaded server
   actually *passes* the held-connection bar (the kernel backlog parks ~1,000 idle sockets for ~9
   MiB — see `reference/baseline-results.csv`). The real tell is the **`ab -c 200` latency on `/io`**:
   p50 ≈ **5 seconds**, p99 ≈ **10 seconds**. Two hundred connections each want a 50 ms `/io` sleep,
   but the one thread serializes them, so they queue for seconds. *That* — not the connection count
   — is "one server isn't enough": the collapse of *service* under concurrent I/O.

This establishes the baseline row and the four-models framing. (The held-connection *wall* shows up
later at Silver — 10k connections exceed the ~4k backlog, so single-thread/thread-pool get refused
while async holds them all. See `reference/DRY-RUN-FINDINGS.md`.)

## Reflect-quiz  (AskUserQuestion)
**Question:** Which model is the right fit for **thousands of idle/slow held connections** — the
C10K shape we just failed?
- ✅ **Fibers** — cheap per connection, idle ≈ free (the C10K win; Steps 11–14).
- ❌ "Fork (a process per connection)." → A whole process each → OOMs in the hundreds.
- ❌ "A thread pool." → Bounded workers; held connections back up at the pool + backlog.
(The other shapes map too: CPU-parallel work → processes/Ractors; I/O-bound → threads or fibers.)
**Next:** Step 4 — start the process family with fork. `/c10k-dojo:next`.
