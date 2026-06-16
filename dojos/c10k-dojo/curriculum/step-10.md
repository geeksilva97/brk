---
step: 10
title: When threads bite
chapter: 11
session: 2
spine: workspace/thread_race.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 10 — When threads bite

## Frame
Threads share memory — that's their power and their knife edge. A Rack app with shared mutable state,
served by a thread pool, will corrupt that state under concurrency. We'll *cause* a race, watch it
fail intermittently, then fix it with a `Mutex`.

## Diagnose-quiz  (AskUserQuestion)
**Question:** A shared `@counter += 1` in the app, hit by many threads. Why does the final count come
out *less* than the number of requests?
- ✅ **`+= 1` is read-modify-write — not atomic; threads interleave and lose updates (a data race).**
  Confirm.
- ❌ "The GVL makes it atomic." → The GVL can switch threads *between* the read and the write; it does
  not make `+=` atomic.
- ❌ "Requests are being dropped." → No; the requests run, the *updates* are lost.

## Spine  (`workspace/thread_race.rb`, ~12 lines)
Take the Step-9 pool. Add an app with a shared counter incremented per request and returned. Run it
under load → observe wrong totals. Then wrap the increment in a `Mutex#synchronize` and re-run.

**Read first:** `docs/ri-dump/Mutex.txt`, `docs/ri-dump/ConditionVariable.txt`.

## Agent role
- `[explain]` Read-modify-write races; what the GVL does and doesn't guarantee; `Mutex`/`Queue`.
- `[review]` Is the *whole* read-modify-write inside the lock (not just part)?

## Gotchas
- Locking too little (only the write) — still races.
- Locking too much — serializes everything, kills the point of threads.
- The race is intermittent: must run under real concurrency to surface it.

## Success check
Before fix: total < requests, varying per run. After `Mutex`: total == requests, every run.
(WEBrick aside: thread-per-connection with 1990s defaults — a cautionary counter-example.)

## Reflect-quiz  (AskUserQuestion)
**Question:** Threads cap out on memory/contention well before C10K. What if one thread could juggle
thousands of connections cooperatively?
- ✅ **Fibers — cheap, cooperative, one thread, no per-connection stack cost.**
- ❌ "More threads." → We just hit that wall (stacks + contention).
- ❌ "More processes." → Even heavier than threads.
**Next:** Step 11 — fibers from scratch. `/c10k-dojo:next`.
