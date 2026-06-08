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

## Diagnose-quiz  (AskUserQuestion)
**Question:** All N workers call `accept` on the *same* inherited listening socket. What happens when
one connection arrives?
- ✅ **The kernel wakes exactly one worker to handle it (load-balanced across workers).** Confirm.
- ❌ "All workers wake and race / get duplicate connections." → No; `accept` on a shared socket hands
  the connection to one waiter (modern kernels avoid the old thundering-herd).
- ❌ "You need a lock so only one worker accepts." → Not for basic preforking; the kernel handles it.

## Design-quiz  (AskUserQuestion)
**Question:** The cage pins to one core (`--cpuset-cpus=0`), so `Etc.nprocessors` honestly returns
1. How many workers should you spawn?
- ✅ **A hardcoded N (say 4–8), deliberately oversubscribing the single core** so I/O-bound workers
  overlap while one waits. Spawning `Etc.nprocessors` (=1) here would give you a single worker —
  no better than Step 4's parent. The point is choosing N on purpose.
- ❌ "Exactly `Etc.nprocessors`." → On this 1-core cage that's 1 worker; you want a few, since web
  work is mostly waiting. (Historical note: with `--cpus=1` quota instead of cpuset, `nproc` would
  *lie* and report all host cores — autodetecting then overspawns. We use cpuset to avoid that.)

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

## Reflect-quiz  (AskUserQuestion)
**Question:** A worker process crashes. With preforking as built so far, what happens?
- ✅ **Nothing replaces it — you silently lose capacity until you have none left.**
- ❌ "The OS restarts it." → The kernel doesn't respawn your workers.
- ❌ "The master re-forks it." → Not yet — we haven't built a master. That's next.
**Next:** Step 6 — a master process that supervises. `/c10k-dojo:next`.
