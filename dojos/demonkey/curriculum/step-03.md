---
step: 3
title: Why one server is not enough
spine: "-"
kind: demo
reference: rack_server.rb
---

# Step 3 — Why one server is not enough (see it block)

## Frame
No new code this step. We make the single-threaded server's limitation *visible* — locally, with two
terminals and `curl`. You're going to watch one slow request freeze the whole server, and feel why
"serve one client at a time" is the wall the process family exists to climb. There's no benchmark
here, just your own eyes.

## What we're about to do  (no spine — there's nothing to build this step)
This step is pure observation: we run the Step-2 server and watch a slow request stall a fast one.
**How you'll validate the claim:** `time curl` in two terminals — the timings are the whole proof.
We run the demo *first*, then talk about why it happened. Don't predict; watch.

## The demo  (drive it with the learner)
1. Make sure the Step-2 server is running: `bundle exec ruby workspace/rack_server.rb`
   (the `config.ru` from setup has a `/slow` route that sleeps 3s and a `/` route that's instant).
2. In terminal A: `time curl -s http://127.0.0.1:4000/slow` (this will take ~3s).
3. *Immediately* in terminal B: `time curl -s http://127.0.0.1:4000/`.
4. Read the two timings **with the learner.** The instant `/` request took ~3 seconds too, because
   it queued behind the slow one. One slow request stalled an unrelated fast one — *that* is "one
   server isn't enough": the collapse of service under concurrent load, on a single process.

(Optional second demo: hold a raw `nc 127.0.0.1 4000` open without sending a full request, then try
`curl /` — it hangs until you close the `nc`. A single idle client can wedge the whole server.)

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks open-ended questions; the learner types their understanding in their own words.
     Scored 1–5; feedback given; retry once if score < 3. -->

Now that the timings are on screen, run these as comprehension checks about what just happened.

**Question 1:** You just watched it: the `/slow` request sleeps 3s, and the instant `/` request fired a
split second later *also* took ~3 seconds. Why did the fast one wait?
A good answer covers: the one process is stuck in `app.call` for client 1; client 2's connection sits
in the kernel backlog until `accept` is reached again; service collapses under a single slow request;
the TCP connection is accepted, but it can't be *served* until the first finishes.

**Question 2:** We saw one process serialize everything. What's the *first, oldest* Unix answer to
"serve more than one client at once"?
A good answer covers: give each connection its own process — `fork`; it's the simplest model to
reason about, and where the process family begins; non-blocking `accept` alone doesn't give you a
second worker; a faster core still serves requests one at a time — the limit is structural.

**Next:** Step 4 — fork a process per connection. `/demonkey:next`.
