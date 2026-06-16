---
step: 4
title: Fork-per-connection
spine: workspace/fork_echo.rb
kind: tcp
reference: fork_echo.rb
---

# Step 4 — Fork-per-connection

## Frame
The first answer to "serve more than one client" is the oldest one: `fork`. When a connection
arrives, copy the whole process; the child handles that one client while the parent goes back to
`accept`. It's the simplest model to reason about — and the first to teach you a brutal lesson about
the cost of a process.

## Teach the mechanism  (fork + reaping are NEW — explain before they build)
Processes are new to a Ruby-only learner. Teach these (one-liner or leading question each), then point
at the docs:
- **`fork`** copies the whole process — both child and parent return from it, distinguished by the
  return value. After the fork, *both* hold the listening socket AND the just-`accept`'d connection
  socket. So each must `close` the fd it doesn't use (work out which, in beat 2 → that's the design
  reasoning, not something to hand them).
- **Copy-on-write:** `fork` is cheap to *start* (pages shared until written), but each child is still
  a whole process — thousands of connections means thousands of processes. That's the wall.
- **Zombies + reaping:** a finished child stays a `<defunct>` **zombie** until the parent **reaps**
  it. Teach the `Process` reaping options and the blocking-vs-non-blocking trade-off; let them pick
  and write the call.

**How you'll validate it:** once it's running you'll open *two* `nc` clients at once (both should
echo now), then watch `ps` for child processes and `<defunct>` zombies, and `lsof` for fd leaks —
full intros when we run them.

**Read first:** `docs/man/fork.txt`, `docs/man/wait.txt`, `docs/ri-dump/Process.txt`.

## Spine  (the learner types `workspace/fork_echo.rb`, ~8 lines)
Start from `workspace/echo.rb`. The shape (you taught the pieces in beat 2 — don't hand the code):
for each accepted connection, `fork` a child that handles it while the parent loops back to `accept`.
They must reason through two things themselves: which socket each process keeps vs. closes after
`fork`, and which `Process` call reaps finished children.

## Agent role
- `[explain]` From `docs/man/fork.txt` + `docs/ri-dump/Process.txt`: which fds the child inherits, why
  the closes matter, what a zombie is and how reaping clears it. macOS note: `signal(3)`.
- `[review]` Check the four classic bugs (below) by line — do NOT rewrite the file.
- *Hard-mode option:* let a small local model write the spine, then have the learner hunt its bug.

## Gotchas (the four classic fork bugs)
1. Child doesn't close the listening socket → fd leak, messy shutdown.
2. Parent doesn't close the accepted connection → fd leak per connection → "too many open files".
3. No reaping → `<defunct>` zombie processes accumulate.
4. `fork` placed inside the *read* loop instead of per-`accept` → forks on every chunk of data.

## Success check  (local — nc, ps, lsof)
1. `ruby workspace/fork_echo.rb`; open two `nc 127.0.0.1 3000` at once → **both echo** (unlike Step 1).
2. While clients are connected, in another terminal:
   `ps -o pid,ppid,stat,command | grep '[r]uby'` → you should see a child process per live connection.
3. Disconnect the clients, wait a beat, then `ps -o pid,stat,command | grep defunct` → **no rows**
   (no zombies — proves your reaping works). If you see `<defunct>`, gotcha #3 bit you.
4. `lsof -p <parent_pid> | grep -c TCP` before vs. after a burst of connect/disconnects → the count
   should return to baseline (proves the parent isn't leaking accepted-connection fds — gotcha #2).

The learner must explain which fd lives in which process after fork, and predict the leak if a
`close` is removed, before advancing.

## See it blow — the memory benchmark  (`/demonkey:bench`)
Local `nc`/`ps` proves it *works*; the bench proves it *doesn't scale*. Run the memory benchmark
against this server in a memory-capped container:

`/demonkey:bench`  (or directly: `KIND=tcp "${CLAUDE_PLUGIN_ROOT}/env/bench/run.sh" workspace/fork_echo.rb 300 192m`)

It holds an accumulating wave of idle connections (75 → 150 → 225 → 300) against the server inside a
**192MB** cgroup and samples peak RSS. Watch what happens: each held connection is a whole forked
process (~1MiB+ of RSS), so RSS **climbs with the connection count** — and at ~150 connections it
blows past the budget and the kernel **OOM-kills it** (`oom=true`, exit 137). That is the wall this
model hits, made concrete. **The lesson: a process per connection means memory grows with load until
it blows.** Step 5 runs this *same* bench against a preforking server — keep this OOM number to
compare.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks open-ended questions; the learner types their understanding in their own words.
     Scored 1–5; feedback given; retry once if score < 3. -->

Now that both clients echoed and you've watched the bench OOM-kill it, run these as comprehension
checks about what you built and saw.

**Question 1:** Your fork server now echoes to two clients at once — the Step-1 hang is gone. What did
`fork` change that fixed it?
A good answer covers: each connection gets its own process with its own copy of the accept'd socket,
so the parent is free to return to `accept` immediately; `accept` still blocks — but only in the
parent, briefly, between connections; `fork` uses copy-on-write, but each child is still a whole
process — thousands of connections means thousands of processes.

**Question 2:** After `fork`, both parent and child held the *listening* socket AND the just-`accept`'d
connection socket. In your code, which closed which — and why?
A good answer covers: child closes the listening socket; parent closes the accepted connection socket;
each process keeps only the fd it actually uses; if the parent doesn't close the accepted connection,
it leaks one fd per connection → "too many open files"; if the child closes the listening socket, the
parent can't accept the next client.

**Question 3:** fork-per-connection works — but you just spawned one whole process for every single
connection. What goes wrong as connections climb into the thousands?
A good answer covers: a process per connection doesn't scale — thousands of processes blow memory
and the PID/fork cost dominates; fork trades memory for concurrency, and per-connection is the worst
case for that trade; under `/demonkey:bench` this server's RSS climbed with every held connection
and got OOM-killed at ~150 connections in a 192MB cage.

**Next:** Step 5 — stop forking per-connection; fork a *fixed pool* up front. `/demonkey:next`.
