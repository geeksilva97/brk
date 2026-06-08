---
step: 16
title: Ractor-based server
chapter: 17
session: 4
spine: workspace/ractor_server.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 16 — A Ractor-based server (demonstration)

## Frame
Can we build a server where Ractors handle requests in true parallel? Yes — as a toy. The honest
finding: it works for trivial apps, but the ecosystem (Rack, common middleware, most gems) assumes
shared mutable state, so a real Rails app won't run unchanged. This step is a frank demonstration of
the frontier, not a C10K contender.

## Diagnose-quiz  (AskUserQuestion)
**Question:** What's the *first* thing that breaks when you try to serve a normal Rack middleware
stack from inside a Ractor?
- ✅ **Shared, mutable global state — middleware/config/loggers that aren't Ractor-shareable raise on
  access.** Confirm; this is the ecosystem gap.
- ❌ "Performance." → It's correctness/sharing first; performance is secondary.
- ❌ "Nothing — Rack is Ractor-safe." → It largely isn't, today.

## Spine  (`workspace/ractor_server.rb`, ~20 lines)
A minimal Ractor-per-request (or a small Ractor pool fed accepted connection fds): accept in the main
thread, pass the connection to a Ractor that serves a *trivial* inline app. Document, in comments,
exactly what breaks when you reach for anything shared.

**Read first:** `docs/ri-dump/Ractor.txt`, the Step-2 cheatsheet.

## Agent role
- `[explain]` What must be shareable to cross the Ractor boundary; why sockets/fds are awkward to pass.
- `[review]` Is the served app genuinely isolated (no shared mutable state)? Are the limits documented?

## Gotchas
- Passing a socket/connection into a Ractor is itself fiddly (object shareability).
- Trying to reuse the Step-2 `build_env`/app if it touches shared state → errors.

## Success check
Serves simple requests in parallel across Ractors; the moment you add shared middleware it raises.
The learner can articulate *why* this isn't production-ready in 2026 (the talk's punchline).

## Reflect-quiz  (AskUserQuestion)
**Question:** You've built all four models. For a typical I/O-bound Rails app on a multi-core box,
which would you reach for?
- ✅ **Threads or fibers (often processes×threads, like Puma) — I/O work overlaps cheaply; Ractors
  aren't ready for shared-state Rails.** This is a judgment call — accept a well-reasoned pick.
- ❌ "Ractors — they're the newest." → Newest ≠ ready; Rails' shared state breaks Ractor isolation.
- ❌ "Fork-per-connection — simplest." → Dies on memory under real load.
**Next:** Step 17 — benchmark everything + the decision tree. `/c10k-dojo:next`.
