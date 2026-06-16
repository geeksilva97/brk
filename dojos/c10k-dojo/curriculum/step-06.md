---
step: 6
title: "Master process: signals & reaping"
chapter: 6
session: 1
spine: workspace/master.rb
kind: tcp
reference: first_socket.rb
---

# Step 6 — The master process: signals & reaping

## Frame
A production preforking server has a **master** that doesn't `accept` at all — it supervises. It
spawns workers, replaces them when they die, and translates Unix signals into actions
(`TERM`/`INT`/`QUIT` shut down, `HUP` reloads, `TTIN`/`TTOU` add/remove workers). This step is about
the supervisor and the signal protocol.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** A worker dies. How does the master find out and replace it without busy-polling?

A good answer covers: the kernel sends the master `SIGCHLD`; the handler reaps with
`Process.wait(-1, WNOHANG)` in a loop and forks a replacement. Busy-polling with `Process.wait`
constantly is wasteful; signal-driven is the point. Workers can't reliably signal their own crash
over a pipe; `SIGCHLD` is the mechanism.

**Question 2:** Why can't you do real work (fork, log, allocate) directly inside a signal trap?

A good answer covers: signal handlers run at unsafe moments; do the minimum and defer. The self-pipe
trick turns a signal into a readable fd the main loop handles safely. You cannot do anything in a
trap — async-signal-unsafe calls can deadlock or corrupt.

## Spine  (`workspace/master.rb`, ~20 lines)
From `workspace/prefork.rb`: add a master loop that traps `CHLD`/`TERM`/`TTIN`/`TTOU` (write a byte
to a self-pipe), selects on the pipe, reaps dead workers with `WNOHANG`, re-forks replacements, and
adjusts worker count on `TTIN`/`TTOU`.

**Read first:** `docs/man/sigaction.txt`, `docs/man/signal.txt` (section 3 on macOS!), `docs/ri-dump/Signal.txt`.

## Agent role
- `[explain]` `SIGCHLD` + `WNOHANG` reaping; the self-pipe trick and why it exists.
- `[review]` Is trap work minimal (just the self-pipe write)? Is the reap a *loop* (multiple children
  can die between wakeups)?

## Gotchas
- Doing heavy work in the trap → deadlock.
- Reaping only one child per `SIGCHLD` → zombies pile up under load.
- Forgetting to re-arm / racing on the worker count.

## Success check
Run it; `kill -TTIN <master>` adds a worker, `-TTOU` removes one (watch `ps`). `kill -9` a worker →
master respawns it within a moment. `kill -TERM <master>` → clean shutdown of all workers.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** The master can reap and respawn dead workers. What's still missing for production?

A good answer covers: stuck-worker recovery + zero-downtime restart — heartbeats/timeouts and USR2.
A worker wedged on a bad request still hangs forever. Just adding more workers fixes neither a stuck
worker nor a deploy that drops connections.
**Next:** Step 7 — production-grade preforking. `/c10k-dojo:next`.
