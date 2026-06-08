---
step: 7
title: Production-grade preforking
chapter: 7
session: 1
spine: workspace/unicorn_like.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 7 — Production-grade preforking ("what makes Unicorn Unicorn")

## Frame
The master from Step 6 plus the Rack server from Step 2 = a real preforking HTTP server. Now add the
production features: heartbeats so the master can kill a stuck worker, graceful shutdown so in-flight
requests finish, and `USR2` zero-downtime restart. Build these as **incremental sub-steps** — small
models (and humans) do one capability at a time.

## Diagnose-quiz  (AskUserQuestion)
**Question:** A worker is stuck in an infinite loop on a bad request. How does the master notice and
recover?
- ✅ **Workers touch a heartbeat (mtime of a file / pipe write) each request; the master kills and
  replaces any worker whose heartbeat is older than a timeout.** Confirm.
- ❌ "The master inspects the worker's CPU usage." → Indirect and unreliable; heartbeats are explicit.
- ❌ "It can't — that's why you need a load balancer." → The master can and should time workers out.

## Design-quiz  (AskUserQuestion)
**Question:** For `USR2` zero-downtime restart, how does the *new* master serve traffic while the old
one drains?
- ✅ **The listening socket fd is inherited across the exec, so the new master accepts on the same
  socket; the old master finishes in-flight requests then exits.** Confirm — fd inheritance is the
  trick, and the hard part.
- ❌ "It opens a new socket on the same port." → Would fail with EADDRINUSE; the point is to *share*
  the existing fd.

## Spine  (`workspace/unicorn_like.rb`) — build in three passes
1. Heartbeat + timeout kill (master kills workers past the deadline).
2. Graceful `QUIT` (stop accepting, finish in-flight, exit).
3. `USR2` re-exec with inherited socket fd; old master drains.
(Marry Step 6's master with Step 2's per-connection HTTP serving.)

**Read first:** `docs/ri-dump/Process.txt`, `docs/ri-dump/Signal.txt`, the Step-2 cheatsheet.

## Agent role
- `[explain]` fd inheritance across `exec`; graceful-shutdown sequencing.
- `[review]` per sub-step. The USR2 fd-passing is the most likely `/c10k-dojo:reveal` moment — that's
  fine; it's genuinely the hardest part of the whole process family.

## Gotchas
- Killing workers mid-request instead of draining.
- Losing the listening socket fd across `exec` (must clear close-on-exec / pass the fd number).
- Heartbeat written too rarely → false timeouts under slow requests.

## Success check
Run it; start a `holder` against `/`; `kill -USR2 <master>` → new master serves with **0 dropped
connections** during the swap. `/c10k-dojo:bench` (Silver attempt): note it still caps at ~N workers
for *held* connections — preforking wins on isolation, not on C10K. *(Step 8 = Pitchfork discussion:
CoW defeat by GC, Shopify's mold/refork — reflect-quiz only, no build for that aside.)*

## Reflect-quiz  (AskUserQuestion)
**Question:** Preforking gives bulletproof isolation, but each worker is a whole process. What if you
want many concurrent requests *inside* one process?
- ✅ **Threads — shared memory, many requests per process.**
- ❌ "More processes." → That's the heavy cost we're trying to get away from.
- ❌ "Not possible in Ruby." → It is — threads next, then fibers.
**Next:** Step 8 — threads and the GVL. `/c10k-dojo:next`.
