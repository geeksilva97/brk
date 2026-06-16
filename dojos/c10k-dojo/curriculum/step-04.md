---
step: 4
title: Fork-per-connection
chapter: 4
session: 1
spine: workspace/fork_echo.rb
kind: tcp
reference: first_socket.rb
---

# Step 4 — Fork-per-connection

## Frame
The first answer to "serve more than one client" is the oldest one: `fork`. When a connection
arrives, copy the whole process; the child handles that one client while the parent goes back to
`accept`. It's the simplest model to reason about — and the first to teach you a brutal lesson about
memory. First, make sure you understand what `fork` actually does.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** Your echo server hangs on the second client (Step 1). Which is the *most direct* reason
`fork` fixes that?

A good answer covers: each connection gets its own process with its own copy of the accept'd socket,
so the parent is free to return to `accept` immediately. `fork` doesn't make accept non-blocking —
`accept` still blocks, but only in the parent, briefly, between connections. Fork uses copy-on-write,
but Ruby's GC writes to most pages quickly, so each child's RSS grows — that's the trap this step
exposes.

**Question 2:** After `fork`, both the parent and the child hold the *listening* socket AND the just-
`accept`'d connection socket. Which closes must happen?

A good answer covers: child closes the listening socket; parent closes the accepted connection socket.
Each process keeps only the fd it actually uses. If only the child closes things, the parent leaks one
fd per connection. Neither can skip closing — they're independent descriptors but share the underlying
socket; leaking them still exhausts the fd table.

## Spine  (the learner types `workspace/fork_echo.rb`, ~8 lines)
Start from `workspace/echo.rb`. Type the fork block by hand — every line is the lesson:
- inside the accept loop, `pid = fork do ... end`,
- in the child: close the listening socket, run the echo, then `exit`,
- in the parent: close the accepted connection socket, then reap children so they don't become
  zombies — `Process.detach(pid)` *or* a non-blocking `Process.wait(-1, Process::WNOHANG)` sweep.
  Add a one-line comment saying which you chose and why.

**Read first:** `docs/man/fork.txt`, `docs/ri-dump/Process.txt`.

## Agent role
- `[explain]` From `docs/man/fork.txt` + `docs/ri-dump/Process.txt`: which fds the child inherits, why
  the closes matter, what a zombie is and how reaping clears it. macOS note: no `epoll`, `signal(3)`.
- `[review]` Check the four classic bugs (below) by line — do NOT rewrite the file.
- *Hard-mode option:* let a small local model write the spine, then have the learner hunt its bug.

## Gotchas (the four classic fork bugs)
1. Child doesn't close the listening socket → fd leak, messy shutdown.
2. Parent doesn't close the accepted connection → fd leak per connection → "too many open files".
3. No reaping → `<defunct>` zombie processes accumulate.
4. `fork` placed inside the *read* loop instead of per-`accept` → forks on every chunk of data.

## Success check
1. `ruby workspace/fork_echo.rb`; two `nc 127.0.0.1 3000` at once → **both echo** (unlike Step 1).
2. `ps -o pid,stat,command | grep ruby | grep defunct` → **no rows** (no zombies).
3. Then `/c10k-dojo:bench` (Bronze, tcp) → **OOM-killed (exit 137) at 1,000 connections** (verified
   in `reference/baseline-results.csv`). Counterintuitive payoff: fork **fails Bronze where the
   single-threaded echo passed** — because fork is *too eager*. A process per connection blows
   256 MB; the single-thread server just parked the same 1,000 idle sockets in the backlog for
   7 MiB. (Even trivial echo children OOM by ~1,000 via process count; with app-sized children
   dirtying pages it OOMs far sooner.)

Learner must explain which fd lives in which process after fork, and predict the leak if a `close` is
removed, before advancing.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** It OOM'd at 1,000 connections while the single-threaded echo survived the same 1,000.
Why does fork-per-connection hit a memory wall the single-thread server doesn't?

A good answer covers: each connection is a *whole process*; 1,000 of them (× baseline RSS, and more
once children dirty pages) blow past 256 MB — whereas the single-thread server just parks idle sockets
in the kernel backlog for almost nothing. Fork trades memory for concurrency, and idle holds are the
worst case for that trade.
This motivates Step 5: stop forking per-connection; fork a *fixed pool* up front. `/c10k-dojo:next`.
