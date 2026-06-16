---
step: 12
title: The Fiber scheduler
chapter: 13
session: 3
spine: workspace/scheduler.rb
kind: demo
reference: rack_based_servers/server.rb
---

# Step 12 — The Fiber scheduler (Ruby 3+)

## Frame
Ruby 3 added a hook: install a `Fiber::Scheduler` and suddenly blocking calls (`IO#read`, `sleep`,
`Socket#accept`) *transparently* yield the fiber and resume it when ready. You write straight-line
blocking-looking code; the scheduler turns it into an event loop under you. The `async` gem ships a
production scheduler — using it is allowed (it's the runtime, not a server).

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** With a fiber scheduler installed, you run three `sleep 1` calls concurrently in three
fibers. Total wall-clock time?

A good answer covers: ~1 second — the scheduler parks each sleeping fiber and runs the others; they
overlap. Without a scheduler it would be ~3 seconds (sequential). The scheduler makes `sleep` yield;
it doesn't error — you can sleep in a fiber when a scheduler is present.

**Question 2:** On macOS, what does the scheduler use under the hood to know when an fd is ready?

A good answer covers: `kqueue`/`kevent` (the BSD/macOS mechanism) — abstracted away from you. **TRAP:**
`epoll` is Linux-only; it does not exist on macOS. Don't write it.

## Spine  (`workspace/scheduler.rb`, ~12 lines)
`require "async"`; inside `Async do |task| ... end`, spawn three subtasks that each `sleep` and print;
observe they overlap. (You're learning the scheduler, not building the server yet.)

**Read first:** `docs/ri-dump/Fiber_Scheduler.txt`, `docs/man/kqueue.txt`, `docs/man/README.md`.

## Agent role
- `[explain]` `Fiber::Scheduler` hook; how blocking IO becomes non-blocking; kqueue (not epoll) on macOS.
- `[review]` If the learner (or a small model) reaches for raw `epoll`/`IO.select` plumbing, redirect
  to the scheduler — that's the lesson.

## Gotchas
- Reaching for Linux `epoll` (doesn't exist here).
- Doing blocking C-extension work that doesn't yield (starves the loop — ties back to Step 11).

## Success check
Three concurrent `sleep 1`s complete in ~1s total, not ~3s. Learner explains *why*.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** If `accept` and `read` now yield instead of blocking, how many connections can one
thread hold?

A good answer covers: thousands — each is a cheap parked fiber; idle ones cost almost nothing.
Yielding is exactly what lets them overlap, so it's not one at a time like before. Capacity is
per-connection memory, not CPU cores — it's one thread.
**Next:** Step 13 — the Falcon-like async server (the C10K win). `/c10k-dojo:next`.
