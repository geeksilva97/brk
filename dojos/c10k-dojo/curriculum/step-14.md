---
step: 14
title: When fibers win, when they don't
chapter: 15
session: 3
spine: workspace/falcon_like.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 14 — When fibers win, when they don't

## Frame
Fibers crushed C10K because web work is mostly *waiting* (I/O). But a fiber that does CPU-bound work
blocks the entire event loop — there's still one thread and one GVL. The honest boundary: fibers win
for slow clients, long-poll, websockets, many idle connections; they do nothing for CPU-bound work.
The pro move is composing fibers with processes/threads.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** You add a `/cpu` (heavy computation) endpoint to the async server and hammer it. What
happens to the *other* connections during a `/cpu` request?

A good answer covers: they stall — the CPU work never yields, so the single thread is monopolized;
the whole loop freezes until it finishes. They're not unaffected — only I/O yields under fibers; CPU
work doesn't yield. The scheduler can't preempt the CPU fiber — cooperative scheduling can't preempt.

## Spine  (extend `workspace/falcon_like.rb`)
No new file — exercise the existing async server's `/cpu` path under load and contrast with `/io`.
Optionally sketch the composition: async front + a process/thread pool for CPU offload.

## Agent role
- `[explain]` Why CPU-bound ≠ helped by fibers; the GVL is still there; composition patterns.
- `[review]` Does the learner correctly predict the stall before running?

## Gotchas
- Concluding "fibers are always best" — they're best for I/O concurrency, not CPU.

## Success check
`/c10k-dojo:bench` on `/cpu` shows the async server is **no better than the thread pool** for CPU
work (often worse, since it's one thread). `/io` stays flat to tens of thousands. The contrast is the
lesson.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** Fibers gave I/O concurrency but not CPU parallelism (one thread, the GVL). What
primitive gives *real* parallel CPU across cores?

A good answer covers: Ractors — true parallelism, each with its own GVL. More fibers won't help —
fibers share one thread/core; they don't parallelize CPU. Threads on MRI are also GVL-pinned for
CPU work.
**Next:** Step 15 — Ractors. `/c10k-dojo:next`.
