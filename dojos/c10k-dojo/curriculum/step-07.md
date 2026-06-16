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

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** A worker is stuck in an infinite loop on a bad request. How does the master notice and
recover?

A good answer covers: workers touch a heartbeat (mtime of a file / pipe write) each request; the
master kills and replaces any worker whose heartbeat is older than a timeout. The master doesn't
inspect CPU usage — that's indirect and unreliable; heartbeats are explicit. It can and should time
workers out; you don't need a load balancer for this.

**Question 2:** For `USR2` zero-downtime restart, how does the *new* master serve traffic while the old
one drains?

A good answer covers: the listening socket fd is inherited across the exec, so the new master accepts
on the same socket; the old master finishes in-flight requests then exits. It does NOT open a new socket
on the same port — that would fail with EADDRINUSE; the point is to *share* the existing fd.

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

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** Preforking gives bulletproof isolation, but each worker is a whole process. What if you
want many concurrent requests *inside* one process?

A good answer covers: threads — shared memory, many requests per process. More processes would be
the heavy cost we're trying to get away from. It is possible in Ruby — threads next, then fibers.
**Next:** Step 8 — threads and the GVL. `/c10k-dojo:next`.
