---
step: 15
title: Ractors
chapter: 16
session: 4
spine: workspace/ractor_pool.rb
kind: demo
reference: first_socket.rb
---

# Step 15 — Ractors

## Frame
Ractors are Ruby's answer to true parallelism without the GVL: each Ractor has its own GVL and runs
on its own core. The catch is isolation — Ractors can't freely share mutable objects; they
communicate by copying or moving, and most objects must be frozen/shareable. This is why most Ruby
code (and Rack) can't drop into a Ractor unchanged. Ties directly to your RubyConf talk.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** You try to pass a mutable `Hash` into a Ractor and use it from both sides. What happens?

A good answer covers: a sharing error — Ractors don't share mutable state; you must freeze/make-shareable,
copy, or move it. The isolation is the feature *and* the friction. Threads allow sharing mutable state
but that's the danger; Ractors forbid it by design. It doesn't silently copy — only for explicitly
shareable/`move:`-d objects; otherwise it raises.

## Spine  (`workspace/ractor_pool.rb`, ~15 lines)
Spawn 2 Ractors that each run a CPU-bound job (e.g. `fib(32)`) and send results back via
`Ractor::Port`/`take`. Compare wall-clock to doing both sequentially — see real 2-core parallelism.
Then deliberately try to share a mutable object and observe the error.

**Read first:** `docs/ri-dump/Ractor.txt`.

## Agent role
- `[explain]` The actor model in Ruby; shareability (frozen/`Ractor.make_shareable`); copy vs move.
- `[review]` Are values passed by message, not shared references? Is the parallelism real (2 cores)?

## Gotchas
- Expecting to share mutable state (the whole point is you can't).
- 1-vCPU cage hides the parallelism — note this demo wants >1 core to show the win.

## Success check
Two Ractors finish CPU work in ~half the sequential time on a multi-core host (run this one outside
the 1-CPU cage). The sharing attempt raises a clear error.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** Given Ractor isolation (no shared mutable state), what would a Ractor-based web server
need from Rack + middleware?

A good answer covers: everything crossing the boundary must be shareable/frozen or copied — most
middleware isn't, today. Rack is largely not Ractor-safe. Just adding more Ractors doesn't solve the
sharing constraint.
**Next:** Step 16 — a Ractor server (honest demo). `/c10k-dojo:next`.
