---
step: 5
title: Preforking N workers
spine: workspace/prefork.rb
kind: tcp
reference: prefork.rb
---

# Step 5 — Preforking N workers

## Frame
Forking per connection is too expensive. Instead: open the listening socket *once*, fork a fixed
number of worker processes up front, and let them all call `accept` on the same socket. The kernel
load-balances connections across them. This is the core of the Unicorn model — a bounded pool of
processes, paid for once at boot, not per request.

## Teach the mechanism  (shared-socket accept + the pool are NEW — explain before they build)
- **Open the socket *before* the fork.** All workers must inherit the *same* listening fd, so the
  `TCPServer` is created once in the parent, then `fork`ed. (If each worker opens its own, you get
  EADDRINUSE or split pools — that's a gotcha to reason about, not to hand them.)
- **Shared `accept` is safe.** When N workers all block on `accept` on the same socket and a
  connection arrives, the kernel wakes exactly *one* of them — no duplicates, no lock needed (modern
  kernels avoid the old thundering-herd).
- **Pool size is a choice, not a detection.** Teach why a hand-picked N (often oversubscribing cores)
  beats `Etc.nprocessors` for I/O-bound web work — let them reason to it.
- **The parent supervises by waiting.** It blocks on the whole worker group so they aren't orphaned;
  teach the `Process` call that waits on all children.

**How you'll validate it:** once it's running you'll count worker children with `ps`, send lines
through several `nc` clients to see them distribute, and run the *same* memory bench from Step 4 to
watch the result flip.

**Read first:** `docs/ri-dump/Process.txt`, `docs/man/fork.txt`.

## Spine  (`workspace/prefork.rb`, ~14 lines)
From `workspace/fork_echo.rb`, the shape: open the `TCPServer` **once**, then `fork` a fixed N workers
(hardcoded/ENV, default 4) that each loop on `accept` forever; the parent supervises by **waiting on
all of them** so they aren't orphaned. You taught the *why* in beat 2 — they assemble it themselves.

## Agent role
- `[explain]` Shared-socket accept semantics; why the socket is opened *before* the fork (so every
  worker inherits the same fd).
- `[review]` Did the learner avoid auto-detecting the count via `Etc.nprocessors`? Do workers share
  the one socket (not each open their own)? Does the parent wait on its children?

## Gotchas
- Each worker opening its own `TCPServer` instead of inheriting the one → EADDRINUSE or split pools.
- Auto-spawning `Etc.nprocessors` workers → may give you too few on a constrained box.
- Parent exiting without `waitall` → workers orphaned.

## Success check  (local — nc, ps)
1. `WORKERS=4 ruby workspace/prefork.rb` → prints the master pid and worker count.
2. `ps -o pid,ppid,command | grep '[p]refork'` → **4 worker children** under the parent pid.
3. Open several `nc 127.0.0.1 3000` clients and send a line through each → they distribute across
   different worker PIDs (compare memory/RSS to Step 4: CoW means N workers cost far less than N
   forks-per-connection). Held connections beyond N back up — that's the bounded-pool tradeoff.

## See the contrast — the SAME memory benchmark  (`/demonkey:bench`)
Run the *exact same* benchmark that OOM-killed fork-per-connection in Step 4 — same held count, same
memory budget — now against this preforking server:

`/demonkey:bench`  (or directly: `KIND=tcp "${CLAUDE_PLUGIN_ROOT}/env/bench/run.sh" workspace/prefork.rb 300 192m`)

Watch the result flip. Where fork's RSS climbed past 192MB and got OOM-killed at ~150 connections,
preforking holds all **300** connections at a **flat ~9MB** and **survives** (`oom=false`). The
peak RSS does NOT move as the connection wave grows — because the memory cost is a *fixed* pool of N
workers (4 here), paid for once at boot and CoW-shared, **independent of the connection count**.
Pull up `${CLAUDE_PROJECT_DIR}/.demonkey/results.csv`: the fork row (`oom_killed=true`, RSS
climbing) and the prefork row (`oom_killed=false`, RSS flat) sit side by side. **That contrast — same
load, same cage, one dies and one shrugs — IS the value of preforking.**

## Consolidate — quizzes AFTER it works  (AskUserQuestion each)
Now that workers distribute connections and the bench survived, run these as comprehension checks.

### Concept check — shared accept  (AskUserQuestion)
**Question:** Your N workers all call `accept` on the *same* inherited listening socket — and you saw
connections land on different worker PIDs with no duplicates. When one connection arrives, what does
the kernel do?
- ✅ **It wakes exactly one worker to handle it (load-balanced across workers).** Confirm.
- ❌ "All workers wake and race / get duplicate connections." → No; `accept` on a shared socket hands
  the connection to one waiter (modern kernels avoid the old thundering-herd).
- ❌ "You need a lock so only one worker accepts." → Not for basic preforking; the kernel handles it.

### Concept check — pool size  (AskUserQuestion)
**Question:** You spawned a hardcoded N (default 4), not `Etc.nprocessors`. Why pick the count by hand?
- ✅ **A hardcoded N you choose on purpose (say 4–8), often oversubscribing the cores** so I/O-bound
  workers overlap while one waits. Web work is mostly *waiting* on I/O, so matching CPU count exactly
  leaves capacity on the table. The point is choosing N deliberately, not auto-detecting it.
- ❌ "Exactly `Etc.nprocessors`." → A fine *starting* heuristic for CPU-bound work, but web work waits
  a lot; you usually want a few more. And on a constrained/containerized box `nprocessors` can mislead.
- ❌ "As many as possible." → Each worker is a whole process; past a point you just add memory and
  context-switching for no throughput.

### Reflect-quiz  (AskUserQuestion)
**Question:** A worker process crashes (say `kill -9` one of them). With preforking as built so far,
what happens?
- ✅ **Nothing replaces it — you silently lose capacity until you have none left.**
- ❌ "The OS restarts it." → The kernel doesn't respawn your workers.
- ❌ "The master re-forks it." → Not yet — the "master" here just sits in `waitall`; it doesn't
  supervise. That's exactly what's next.
**Next:** Step 6 — a real master process that supervises and respawns. `/demonkey:next`.
