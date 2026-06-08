---
step: 6
title: "Load it: thousands of idle connections"
spine: "-"
kind: check
reference: load_test.rb
---

# Step 6 — Load it: thousands of idle connections

## Frame
You built the reactor; now *feel* why it matters. We open thousands of simultaneous connections to
your `reactor_writes.rb` and watch a single-threaded process hold them all — the exact workload that
would force a thread-per-connection server to spawn thousands of threads (and a fork server thousands
of processes). No new spine here: this is the win-condition for the whole course.

## Diagnose-quiz  (AskUserQuestion)
**Question:** A thread-per-connection server and your reactor both face 5,000 idle-but-open
connections. What's the structural difference in what each holds?
- ✅ **The reactor holds 5,000 *file descriptors* and 5,000 small buffers in one thread; the
  thread-per-connection server holds 5,000 *OS threads*, each with its own stack (~MBs) and scheduler
  overhead.** Same fds, wildly different memory/scheduling cost.
- ❌ "They're equivalent; both keep 5,000 sockets." → The sockets are equal, but a thread per socket
  costs stack + context-switching the reactor never pays.
- ❌ "The reactor needs 5,000 threads too, just hidden." → No — it's genuinely one thread; readiness,
  not threads, is how it waits.

## (No spine this step)
This is a measurement/check step. There is no file to type — you run a load generator against the
server from Step 5 and read the result together.

## Agent role
- `[explain]` What `ulimit -n` (max open fds) is and why it's the real ceiling for a reactor, not
  thread count. How the load generator opens N connections and keeps them idle.
- `[scaffold]` `curriculum/reference/load_test.rb` is GIVEN — a small client that opens N connections,
  sends one line on each, and reports how many stayed live. The learner runs it; they don't write it.
- `[review]` Read the numbers with the learner: at what N does it strain, and is the limit fds
  (`ulimit`) rather than CPU or threads?

## Gotchas
- Hitting the open-file limit (`Errno::EMFILE`) — raise it with `ulimit -n 10000` before the test;
  that's the reactor's real ceiling, and naming it is the lesson.
- Confusing "idle connections held" (capacity) with "requests/sec" (throughput) — this step measures
  capacity.

## Success check
1. In one shell: `ulimit -n 10000 && ruby workspace/reactor_writes.rb`.
2. In another: `ruby curriculum/reference/load_test.rb 5000` (or run the GIVEN load tester) → it
   reports ~5,000 connections held and echoed by the single-threaded reactor without it falling over.
3. The learner explains, out loud, why one thread can hold thousands of connections and what the
   actual ceiling is (open fds, not threads).

## Reflect-quiz  (AskUserQuestion)
**Question:** You've held thousands of connections on one thread. What is the reactor's true scaling
ceiling, and how would you go *past* it?
- ✅ **Open file descriptors per process (`ulimit -n`) and the single core a lone reactor uses — you
  go past it by running multiple reactors (one per core / process) behind the same listening socket.**
  Capacity is fd-bound, throughput is core-bound.
- ❌ "Number of threads." → The reactor uses one thread on purpose; threads aren't the limit.
- ❌ "There is no ceiling." → There is: fds per process and a single core's CPU.

## Course complete
This is the last step — there is no next step. Congratulate the learner: they built a single-threaded
reactor from a blocking accept loop up through `IO.select` multiplexing, per-connection buffering, and
write backpressure, and proved it holds thousands of connections on one thread. Point them to
`/reactor-dojo:status` to review the full ramp, and suggest the natural follow-on topics (a real
protocol on top of the reactor; multi-reactor / SO_REUSEPORT scaling; or Ruby's `Fiber::Scheduler`,
which is a reactor the runtime drives for you).
