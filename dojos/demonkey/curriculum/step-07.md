---
step: 7
title: Production-grade preforking
spine: workspace/unicorn_like.rb
kind: http
reference: unicorn_like.rb
---

# Step 7 — Production-grade preforking ("what makes Unicorn Unicorn")

## Frame
The master from Step 6 plus the Rack server from Step 2 = a real preforking HTTP server. Now add the
three production features that separate a toy preforker from Unicorn: **heartbeats** so the master
can kill a stuck worker, **graceful shutdown** so in-flight requests finish, and **`USR2`
zero-downtime restart**. Build these as **incremental sub-steps** — one capability at a time.

## Teach the mechanism  (the three production features are NEW — explain before they build)
- **Heartbeats + timeout kill.** A worker stuck in an infinite loop is *alive*, so `SIGCHLD` never
  fires — the Step-6 reaper can't help. The fix: each worker touches a per-worker file (updates its
  mtime) every request; the master checks those mtimes on its loop timer and `SIGKILL`s + respawns
  any worker whose heartbeat is older than a timeout.
- **Graceful `QUIT`.** Stop accepting *new* connections, finish what's in flight, then exit — versus
  `TERM`/`INT` which die now.
- **`USR2` zero-downtime re-exec.** The crux: the listening socket's fd must survive the `exec` so a
  *new* master can accept on the **same** socket while the old one drains. Teach fd-across-exec
  (`close_on_exec = false`, pass the fd number, `IO.for_fd` to re-adopt) — this is the hardest piece
  in the whole course, so lean on the docs and `/demonkey:hint`.

**How you'll validate it:** with the learner watching `ps`, you'll tie up a worker with `/wedge` and
watch the master kill+respawn it, then fire `kill -USR2` *during* an in-flight `/slow` and prove the
new master serves with no dropped connection and no EADDRINUSE.

**Read first:** `docs/ri-dump/Process.txt`, `docs/ri-dump/Signal.txt`, `docs/ri-dump/IO.txt`,
the Step-2 cheatsheet, `docs/man/sigaction.txt`.

## Spine  (`workspace/unicorn_like.rb`) — build in three passes
Marry Step 6's master with Step 2's per-connection HTTP serving, then add the three things that make
it production-grade. These are GOALS to derive from the docs, not a recipe — work out the actual
calls yourself (or via `/demonkey:hint`):
1. **Heartbeat + timeout kill.** A worker must continuously prove it's alive; the master kills and
   respawns one that's wedged on a bad request. (What does a worker touch, and when? How does the
   master cheaply detect staleness on its loop timer?)
2. **Graceful `QUIT`.** Stop accepting *new* connections, finish what's in flight, then exit — versus
   `TERM`/`INT` which die now.
3. **`USR2` zero-downtime re-exec.** A fresh master takes over the **same listening socket** while the
   old one drains and exits. The crux: keep that socket's fd alive across the `exec` and have the new
   process re-adopt it. This is the hardest piece in the course — reason from `docs/ri-dump/IO.txt`
   and the Process docs about fds across exec; lean on `/demonkey:hint`, and `/demonkey:reveal`
   is the instructor's safety net if you're genuinely stuck.

Because this builds in three passes, you may **consolidate per pass** — run the matching quiz below
right after the learner has built and watched that capability, rather than saving all three for the end.

## Agent role
- `[explain]` fd inheritance across `exec` (`close_on_exec`, `for_fd`); graceful-shutdown sequencing;
  heartbeat-as-mtime.
- `[scaffold]` The Rack request-handling body can be reused verbatim from Step 2 (it's solved); the
  *new* code is the master-side heartbeat check, the QUIT drain, and the USR2 re-exec.
- `[review]` per sub-step. The USR2 fd-passing is the most likely `/demonkey:reveal` moment — that's
  fine; it's genuinely the hardest part of the whole process family.

## Gotchas
- Killing workers mid-request instead of draining on `QUIT`.
- Losing the listening socket fd across `exec` (forgetting `close_on_exec = false`, or not passing
  the fd number) → the new master can't bind → EADDRINUSE.
- Heartbeat written too rarely → false timeouts on a legitimately slow request.
- The new master not detaching from / racing the old one → double-reap or a zombie master.

## Success check  (local — curl, kill -SIGNAL; this is the climax)
Run `bundle exec ruby workspace/unicorn_like.rb` (the setup `config.ru` has `/`, `/slow` (3s), and
`/wedge` (sleeps far past the timeout)). Then, **with the learner watching `ps`**:
1. **Heartbeat timeout:** `curl http://127.0.0.1:4000/wedge &` ties up a worker; within ~`TIMEOUT`
   seconds the master logs `worker N wedged — SIGKILL` and respawns it. `ps` shows a fresh worker pid;
   `/` still serves.
2. **Zero-downtime USR2:** start a slow request in the background
   `( time curl -s http://127.0.0.1:4000/slow ) &`, then *while it's in flight* `kill -USR2 <master>`.
   Watch the log: a NEW master adopts the inherited fd and comes up serving; `curl http://127.0.0.1:4000/`
   succeeds against it immediately (no EADDRINUSE); the in-flight `/slow` request **completes with no
   dropped connection**; the old master drains and exits. **Zero downtime, proven locally.**
3. **Graceful shutdown:** `kill -QUIT <master>` → workers finish in-flight, then everything exits
   clean (`ps | grep defunct` → no zombies; no leftover heartbeat files).

Reference (instructor): `curriculum/reference/unicorn_like.rb`.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks open-ended questions; the learner types their understanding in their own words.
     Scored 1–5; feedback given; retry once if score < 3. -->

Run these as comprehension checks once the matching capability is built and watched (per pass, or all
at the end).

**Question 1:** You watched the master `SIGKILL` and respawn the worker wedged on `/wedge` — even though
it was *alive*, so `SIGCHLD` never fired. How did the master notice?
A good answer covers: workers touch a heartbeat (mtime of a per-worker file) each request; the master
checks the mtimes on a timer and SIGKILLs + respawns any worker whose heartbeat is older than a
timeout; inspecting CPU usage is indirect and unreliable; the master can and should time workers out.

**Question 2:** You fired `kill -USR2` during an in-flight `/slow`, and a NEW master served `/`
immediately — no EADDRINUSE. How did the new master serve on the same port while the old one drained?
A good answer covers: the listening socket fd is inherited across the exec, so the new master accepts
on the SAME socket; the old master finishes in-flight requests then exits; fd inheritance is the trick
and the hard part — clear close-on-exec, then hand the fd number to the new process; opening a new
socket on the same port would fail with EADDRINUSE; killing old workers first then rebinding is a
window of dropped connections — the opposite of zero-downtime.

**Question 3:** You've built a Unicorn-like preforking server: a supervising master, heartbeats with
timeout-kill, graceful shutdown, and USR2 zero-downtime restart. What does this model still *not* give
you, that motivates the next family of servers (a different course)?
A good answer covers: many concurrent requests *inside one process* — preforking gives bulletproof
isolation, but each worker still serves one request at a time, so a slow request ties up a whole
process; that's what threads (and then fibers) address — a separate course; it's great for isolation
and CPU work, but a process per concurrent request is heavy for I/O-bound, high-concurrency loads;
more USR2 restarts doesn't address per-request concurrency.

**Next:** That's the end of the process family — you've reached the Unicorn-like server. Threads and
fibers are the next course. Run `/demonkey:status` to see the full arc you climbed.
