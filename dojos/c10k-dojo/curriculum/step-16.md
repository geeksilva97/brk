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

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** What's the *first* thing that breaks when you try to serve a normal Rack middleware
stack from inside a Ractor?

A good answer covers: shared, mutable global state — middleware/config/loggers that aren't
Ractor-shareable raise on access. This is the ecosystem gap. It's not about performance —
correctness/sharing comes first. And Rack is largely not Ractor-safe today.

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

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** You've built all four models. For a typical I/O-bound Rails app on a multi-core box,
which would you reach for?

A good answer covers: threads or fibers (often processes×threads, like Puma) — I/O work overlaps
cheaply; Ractors aren't ready for shared-state Rails. Fork-per-connection would die on memory under
real load. This is a judgment call — accept a well-reasoned pick.
**Next:** Step 17 — benchmark everything + the decision tree. `/c10k-dojo:next`.
