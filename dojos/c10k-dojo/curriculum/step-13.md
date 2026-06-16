---
step: 13
title: Falcon-like async server
chapter: 14
session: 3
spine: workspace/falcon_like.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 13 — Building a Falcon-like server → the C10K win

## Frame
This is the headline. One process, one thread, a fiber scheduler — and one fiber per connection.
Idle connections cost almost nothing (a fiber is KBs), so the same Rack app you've served all along
now holds **ten thousand** concurrent connections inside one thread. Same app, same env adapter, new
shape. This is the step that beats C10K.

## Diagnose-quiz  (AskUserQuestion)
**Question:** Why does the async server hold 10k idle/slow connections on 256 MB when the thread pool
choked at a couple thousand?
- ✅ **Each connection is a cheap fiber multiplexed on one thread (no per-connection kernel stack);
  idle fibers parked by the scheduler cost almost nothing.** Confirm.
- ❌ "It uses more cores." → No; still one thread. It's about per-connection cost, not parallelism.
- ❌ "It drops idle connections." → No; it holds them — that's the point.

## Spine  (`workspace/falcon_like.rb`, ~15 lines)
Inside `Async do ... end`: accept in a loop and, for each connection, spawn a subtask
(`task.async { serve(conn) }`) that runs the Step-2 `read_request → build_env → app.call →
write_response` flow. Reuse `build_env`. The accept and the IO now yield via the scheduler
automatically — you write it like blocking code.

**Read first:** `docs/ri-dump/Fiber_Scheduler.txt`, the Step-2 cheatsheet.

## Agent role
- `[explain]` One-fiber-per-connection; how the scheduler overlaps thousands of them.
- `[review]` Is each connection its own subtask? Is the same `build_env`/app reused (orthogonality)?

## Gotchas
- Doing CPU-bound work in a handler (blocks the whole loop — that's Step 14's lesson).
- Forgetting to close connections (fibers leak).

## Success check
`/c10k-dojo:bench silver http` → **Silver C10K PASSES** (measured): **10,000 held, p99 93 ms,
9,570 req/s, 348 MiB, no OOM — on one core.** That's the headline: holding 10k *and* serving at
sub-100 ms p99 with a single CPU. Per-connection cost ≈ 35 KB (fiber + parser buffers), so Silver
runs at 512 MB; at 256 MB async tops out ~9.5k (a great "so close" demo of the budget edge).
Contrast on the same cage: fork OOM'd ~1k, thread-pool capped ~5,140. (`reference/DRY-RUN-FINDINGS.md`.)
**This is the moment** — show the learner the flat memory curve next to fork's cliff (`/c10k-dojo:status`).

## Reflect-quiz  (AskUserQuestion)
**Question:** Did fibers make *everything* faster, or just concurrent I/O cheaper?
- ✅ **Just concurrent I/O — CPU work is still GVL-bound on one thread.**
- ❌ "Everything — fibers are faster across the board." → No; a CPU-bound handler still blocks the loop.
- ❌ "They added parallelism." → One thread, no parallelism — they overlap *waiting*, not computing.
**Next:** Step 14 — when fibers win, when they don't. `/c10k-dojo:next`.
