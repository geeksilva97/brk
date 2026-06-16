---
step: 6
title: "Master process: signals and reaping"
spine: workspace/master.rb
kind: tcp
reference: master.rb
---

# Step 6 — The master process: signals & reaping

## Frame
A production preforking server has a **master** that doesn't `accept` at all — it supervises. It
spawns workers, replaces them when they die, and translates Unix signals into actions
(`TERM`/`INT`/`QUIT` shut down, `TTIN`/`TTOU` add/remove workers). This is the step where your server
stops being a script and becomes a *supervisor*. Two ideas carry it: SIGCHLD-driven reaping and the
self-pipe trick.

## Teach the mechanism  (signals + self-pipe are NEW — explain before they build)
- **SIGCHLD-driven reaping.** When a child dies the kernel sends the master `SIGCHLD`. The handler
  reaps with `Process.wait(-1, WNOHANG)` *in a loop* (one SIGCHLD can stand for several dead
  children) and forks a replacement — no busy-polling.
- **The self-pipe trick + why it exists.** Signal handlers run at unsafe moments, so a trap must do
  the *minimum*: write one byte to a pipe. The main loop, blocked in `IO.select`, wakes when that
  byte is readable and does the real work (fork, log, reap) on a normal stack. Teach *why* the trap
  can't do the work directly (async-signal safety) — that reasoning is the lesson.
- **The signal protocol.** `TTIN`/`TTOU` adjust the worker count; `TERM`/`INT`/`QUIT` shut workers
  down cleanly. A forked worker must reset the master's inherited traps to `DEFAULT`.

**How you'll validate it:** once it's running you'll drive the master entirely with `kill -SIGNAL`
(TTIN/TTOU/-9/TERM) and watch `ps` for the worker count, respawns, and zombies — full signal intros
when we run them.

**Read first:** `docs/man/sigaction.txt`, `docs/man/signal.txt` (section 3 on macOS!),
`docs/man/wait.txt`, `docs/ri-dump/Signal.txt`, `docs/ri-dump/Process.txt`.

## Spine  (`workspace/master.rb`, ~30 lines)
From `workspace/prefork.rb`: turn the parent into a **master** that supervises instead of accepting.
The shape (you taught the *why* in beat 2 — they derive the *how* from the docs, so this is NOT a
recipe):
- the signal traps do the bare minimum, and the main loop does the real work — the **self-pipe trick**;
- the main loop reaps dead children **without blocking** and keeps the pool topped up to N;
- `TTIN`/`TTOU` adjust the worker count; `TERM`/`INT`/`QUIT` shut workers down cleanly (and don't
  leave zombies behind the master).

Work out the actual calls from the docs — what's async-signal-safe, how to reap non-blockingly, how
to wake a blocked `select` from a trap, and how a forked worker should reset its inherited traps.
Stuck on a specific call? `/demonkey:hint` (it points at the doc, then asks, then a `# TODO` skeleton).

## Agent role
- `[explain]` `SIGCHLD` + `WNOHANG` reaping; the self-pipe trick and *why* it exists (async-signal
  safety). The `IO.select` + drain pattern.
- `[review]` Is trap work minimal (just enqueue + poke the pipe)? Is the reap a *loop* (multiple
  children can die between wakeups)? Do fresh workers reset the master's traps to `DEFAULT`?

## Gotchas
- Doing heavy work (fork/log) directly in the trap → deadlock or corruption.
- Reaping only one child per `SIGCHLD` → zombies pile up under load.
- Forgetting to drain the self-pipe → `IO.select` returns immediately forever (busy spin).
- Workers inheriting the master's traps → a `TERM` to a worker gets swallowed instead of killing it.

## Success check  (local — ps, kill -SIGNAL)
1. `WORKERS=2 ruby workspace/master.rb` → master prints its pid + worker count.
2. `kill -TTIN <master>` → a 3rd worker appears (`ps -o pid,ppid,command | grep '[m]aster'`).
3. `kill -TTOU <master>` → back to 2 workers.
4. `kill -9 <one worker pid>` → master respawns it within a moment; worker count returns to target;
   `ps | grep defunct` shows **no zombies** (proves the WNOHANG reap loop).
5. `kill -TERM <master>` → clean shutdown of master and all workers (no orphans, no zombies).

The learner must explain what the self-pipe is doing and why the reap is a loop before advancing.

## Consolidate — quizzes AFTER it works  (AskUserQuestion each)
Now that you've watched the master respawn a `kill -9`'d worker and adjust the pool on TTIN/TTOU, run
these as comprehension checks.

### Concept check — how it noticed  (AskUserQuestion)
**Question:** You `kill -9`'d a worker and the master respawned it — without any polling loop. How did
the master find out the worker had died?
- ✅ **The kernel sent the master `SIGCHLD`; the handler reaps with `Process.wait(-1, WNOHANG)` in a
  loop and forks a replacement.** Confirm — and note the loop: one SIGCHLD can stand for several dead
  children.
- ❌ "The master loops calling `Process.wait` constantly." → Wasteful; signal-driven is the point.
- ❌ "Workers tell the master over a pipe before dying." → They can't reliably signal their own crash;
  `SIGCHLD` is the mechanism the kernel gives you.

### Concept check — the self-pipe  (AskUserQuestion)
**Question:** Your traps just write one byte to the self-pipe; the main loop does the fork/log/reap.
Why couldn't you do that real work directly inside the signal trap?
- ✅ **Signal handlers run at unsafe moments; do the minimum and defer. The self-pipe trick turns a
  signal into a readable fd the main loop handles safely** — the trap writes one byte; the main loop,
  blocked in `IO.select`, wakes and does the real work on a normal stack.
- ❌ "You can do anything in a trap." → Async-signal-unsafe calls can deadlock or corrupt; Ruby's trap
  is safer than C but you still want the trap to be tiny.
- ❌ "Just disable signals during the handler." → That doesn't make the handler's own work safe, and
  you'd miss signals.

### Reflect-quiz  (AskUserQuestion)
**Question:** The master can reap and respawn *dead* workers. What's still missing for production?
- ✅ **Stuck-worker recovery + zero-downtime restart — heartbeats/timeouts and USR2.** A worker wedged
  on a bad request is alive but useless; and a deploy still drops connections.
- ❌ "Nothing — this is production-ready." → A worker stuck in an infinite loop never dies, so SIGCHLD
  never fires for it.
- ❌ "Just more workers." → Count fixes neither a stuck worker nor a deploy that drops connections.
**Next:** Step 7 — production-grade preforking (the unicorn thing). `/demonkey:next`.
