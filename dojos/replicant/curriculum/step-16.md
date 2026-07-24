---
step: 16
title: Heartbeat and failure detection
spine: workspace/heartbeat.rb
kind: build
reference: -
---

# Step 16 — Heartbeat and failure detection

## Frame
Catch-up assumed you already knew the follower came back. But the deeper problem is detection, and it
runs the other way too: a follower cannot tell a *slow* leader from a *dead* one. There is no signal
for "I have crashed." The only thing a node can observe is **silence**. This step builds the standard
answer — periodic heartbeats and a timeout — and forces you to confront that the timeout is a guess.

## Teach the mechanisms
- **Heartbeat.** The leader sends a small periodic `Heartbeat` message to each follower every `T`
  (over the Link, so you can cut it). Its only job is to say "still here."
- **Election timeout.** A follower resets a timer whenever it hears from the leader. If the timer
  fires — no heartbeat for some multiple of `T` — it declares the leader dead. Make the timeout a
  *multiple* of the interval and add a little randomness, so a single delayed heartbeat doesn't trip
  it and so followers don't all fire in lockstep.
- **Why it's fundamentally a guess.** A leader that's alive but slow (GC pause, overloaded link) is
  indistinguishable from a dead one. Short timeout → false alarms; long timeout → slow to react.
  There is no setting that is "correct" — only trade-offs. Run a background thread for the sender and
  a timer on the receiver (see the Thread docs).

## Spine  (the learner types `workspace/heartbeat.rb`, ~25 lines)
A leader thread that sends `Heartbeat` every `T`; a follower that resets its deadline on each
heartbeat and, when the deadline passes, flags "leader dead" (log/emit the event). Route heartbeats
through the Link so you can stop or partition them. The timeout is a multiple of `T`, slightly
randomized.

**Read first:** `docs/wire-protocol-cheatsheet.md` (the `Heartbeat` type), `docs/ri-Thread.txt` (a periodic thread + a timer).

## Agent role
- `[explain]` Walk the interval-vs-timeout relationship and why the timeout must exceed the interval.
  Introduce the timer approach from the Thread docs; don't write it.
- `[review]` Is the timeout strictly greater than the interval (with margin)? Does a single missed
  beat NOT trip it? Does the follower reset its timer on *received* traffic? Is the sender on its own
  thread so nothing else blocks it?

## Gotchas
- Timeout ≤ heartbeat interval → the follower flaps between "alive" and "dead" constantly.
- Tripping on a single missed heartbeat instead of a window / multiple.
- Forgetting to reset the timer when a heartbeat (or any message) arrives.
- Blocking the heartbeat thread on other work so beats stop going out even though the leader is fine.

## Success check
Run leader + follower and watch steady heartbeats. Stop the leader's heartbeats (or partition it on
the Link): the follower flags the leader dead within the timeout. Restore heartbeats: the flag
clears. Then shorten the timeout below the interval and watch it flap — proof the knob matters.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
A perfectly healthy but momentarily slow leader gets declared dead. Which knob in their code did it,
and what breaks if they crank that knob the other way?

**Quiz topic 2 — Design:**
Why detect failure by silence-and-timeout instead of expecting a dying node to send a "goodbye"?

**Quiz topic 3 — Reflect:**
Why can a node never be *certain* another node is dead — only guess? What did watching the flapping
teach you about that?

## Next step
There is one logical next step. Detection is a guess, which means you will sometimes decide a leader
is dead when it isn't — and that mistaken-but-alive leader is dangerous. Then point them to
**Step 17** and run `/replicant:next`.

Next: The generation clock
