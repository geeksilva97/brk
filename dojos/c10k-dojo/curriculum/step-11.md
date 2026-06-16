---
step: 11
title: Fibers from scratch
chapter: 12
session: 3
spine: workspace/fibers.rb
kind: demo
reference: first_socket.rb
---

# Step 11 — Fibers from scratch

## Frame
A fiber is a pauseable function: it can `yield` control and be `resume`d later, keeping its stack.
Cooperative, not preemptive — a fiber runs until *it* decides to yield. They're cheap (no kernel
thread, tiny stack), which is exactly what will let one thread juggle 10,000 connections in Step 13.
First, build intuition with no sockets at all.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** Two fibers, one event loop. Fiber A enters an infinite CPU loop without ever yielding.
What happens to Fiber B?

A good answer covers: B never runs — cooperative scheduling means a fiber that doesn't yield starves
the others. This is the key difference from threads. The scheduler does not preempt A after a time
slice; fibers are not preemptive. They don't run in parallel; it's one thread, one fiber at a time.

## Spine  (`workspace/fibers.rb`, ~15 lines)
Build a generator with `Fiber.new`/`Fiber.yield`/`#resume` (e.g. an infinite naturals generator).
Then hand-schedule two fibers that each `yield` after printing, and a tiny loop that `resume`s them
in turn — see cooperative interleaving by hand.

**Read first:** `docs/ri-dump/Fiber.txt`.

## Agent role
- `[explain]` `resume`/`yield` semantics; why fibers are cheap (no kernel stack); cooperative vs preemptive.
- `[review]` Does the generator preserve state across `resume`? Do the demo fibers actually yield?

## Gotchas
- Forgetting a fiber must `yield` to give others a turn.
- Confusing `Fiber.yield` (pause this fiber) with `return`.

## Success check
The generator yields successive values across `resume` calls; the two demo fibers interleave under
manual scheduling.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** We had to `resume` fibers by hand. Who can call `resume` automatically when a socket
becomes readable?

A good answer covers: a Fiber scheduler — it parks blocked fibers and resumes them on I/O readiness.
The OS scheduler schedules threads/processes, not Ruby fibers. Ruby 3+ added the scheduler hook so
you don't always have to resume manually.
**Next:** Step 12 — the Fiber scheduler. `/c10k-dojo:next`.
