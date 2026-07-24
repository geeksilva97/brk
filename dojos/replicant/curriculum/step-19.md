---
step: 19
title: Majority-quorum election
spine: workspace/quorum_election.rb
kind: build
reference: -
---

# Step 19 — Majority-quorum election

## Frame
Split-brain happened because a node crowned itself on purely local information. The fix is a
**majority quorum**: a candidate becomes leader only if *more than half* of the whole cluster votes
for it. Because two disjoint groups can't both be more than half of the same cluster, only one
partition can ever elect — split-brain becomes impossible.

## Teach the mechanisms
- **Majority = floor(N/2) + 1.** For N=3 that's 2; for N=5 it's 3. Strictly *more than half*, not
  half. The candidate counts itself consistently in N.
- **RequestVote.** A candidate sends `RequestVote` to every peer and counts the grants it gets back.
  It wins only when grants reach a majority; otherwise it stands down and waits.
- **A vote is spent once per generation.** A voter grants at most one vote per generation (tie the
  vote to the generation from the previous step), so two candidates can't both collect a majority in
  the same era.
- **Why a minority can't elect.** A partition holding only a minority literally cannot gather
  majority grants — its candidate never wins, so that side has no leader. That is the safety property,
  and it's why clusters are sized 2f+1 (odd) to tolerate f failures.

## Spine  (the learner types `workspace/quorum_election.rb`, ~30 lines)
On election timeout, become a candidate: send `RequestVote` to peers over the Link, collect grants,
and become leader **only** on a majority. A voter grants at most once per generation. Reuse the
generation, the timeout, and the Link.

**Read first:** `docs/wire-protocol-cheatsheet.md` (`RequestVote` and its grant/deny reply).

## Agent role
- `[explain]` Nail down `floor(N/2)+1` and why it's strictly more than half. Clarify how a
  per-generation vote prevents a double win. Point at the cheatsheet for the message pair.
- `[review]` Is the threshold `> N/2` (not `>= N/2`)? Does a voter refuse a second vote in the same
  generation? Is the candidate counted consistently in N? Is the vote tied to the generation?

## Gotchas
- Using `N/2` as the bar instead of a strict majority (`> N/2`) — lets a tie-sized group elect.
- A voter granting more than once in a generation, letting two candidates both "win."
- Counting self in the numerator but not the denominator (or vice versa), skewing the majority test.
- Not tying a vote to the generation, so stale votes count.

## Success check
Run 3 nodes. Partition 2:1 on the Link and trigger elections. Only the **majority (2)** side elects a
leader; the **minority (1)** side collects at most its own vote and stays leaderless. No split-brain —
contrast directly with the previous step's double-leader run.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Trace the vote count on the minority side of your run: how many grants did its candidate get, and
which line stopped it from declaring victory?

**Quiz topic 2 — Design:**
Why *more than half* specifically? What could a candidate get away with if the bar were exactly half,
or a third?

**Quiz topic 3 — Reflect:**
How does requiring a quorum turn a local, per-node decision into a guarantee that's safe for the whole
cluster?

## Next step
There is one logical next step. Election now picks a single leader safely — but writes still commit on
local append. The same majority idea has to guard *commits*, or a minority leader will happily accept
data it can't protect. Then point them to **Step 20** and run `/replicant:next`.

Next: Quorum commit
