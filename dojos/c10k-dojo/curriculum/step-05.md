---
step: 5
title: Preforking N workers
chapter: 5
session: 1
spine: workspace/prefork.rb
kind: tcp
reference: first_socket.rb
---

# Step 5 — Preforking N workers

## Frame
Forking per connection is too expensive. Instead: open the listening socket *once*, fork a fixed
number of worker processes up front, and let them all call `accept` on the same socket. The kernel
load-balances connections across them. This is the core of the Unicorn model.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** All N workers call `accept` on the *same* inherited listening socket. What happens when
one connection arrives?

A good answer covers: the kernel wakes exactly one worker to handle it (load-balanced across workers).
It's not the case that all workers wake and race / get duplicate connections — `accept` on a shared
socket hands the connection to one waiter (modern kernels avoid the old thundering-herd). You don't
need a lock so only one worker accepts; the kernel handles it.

**Question 2:** The cage pins to one core (`--cpuset-cpus=0`), so `Etc.nprocessors` honestly returns
1. How many workers should you spawn?

A good answer covers: a hardcoded N (say 4–8), deliberately oversubscribing the single core so I/O-bound
workers overlap while one waits. Spawning `Etc.nprocessors` (=1) here would give you a single worker —
no better than Step 4's parent. The point is choosing N on purpose.

## Spine  (`workspace/prefork.rb`, ~12 lines)
From `workspace/fork_echo.rb`: open the `TCPServer` once; `N.times { fork { worker_loop(server) } }`
with a hardcoded N (4–8); `worker_loop` just `accept`s and echoes forever; the parent `Process.wait`s
on all children.

**Read first:** `docs/ri-dump/Process.txt`.

## Agent role
- `[explain]` Shared-socket accept semantics; why the socket is opened before the fork.
- `[review]` Did the learner avoid `Etc.nprocessors`? Do workers share the one socket (not each open
  their own)?

## Gotchas
- Spawning `Etc.nprocessors` workers (=1 on this cage) → no concurrency gain over Step 4.
- Each worker opening its own socket instead of inheriting the one.
- Parent exiting without waiting → workers orphaned.

## Success check
Run it; connect several `nc` clients → watch them distribute across different worker PIDs
(`ps | grep ruby`). Then `/c10k-dojo:bench` (Bronze): handles N concurrent *active*, but held
connections beyond N back up. Compare memory to Step 4 — CoW means N workers cost far less than N
forks-per-connection.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** A worker process crashes. With preforking as built so far, what happens?

A good answer covers: nothing replaces it — you silently lose capacity until you have none left.
The kernel doesn't respawn your workers. We haven't built a master that re-forks yet.
**Next:** Step 6 — a master process that supervises. `/c10k-dojo:next`.
