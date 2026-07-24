---
step: 18
title: Naive election and split-brain
spine: workspace/election.rb
kind: build
reference: -
---

# Step 18 — Naive election and split-brain

## Frame
Until now you appointed the leader by hand. When the real leader dies, the surviving nodes have to
pick a new one on their own. The tempting rule is simple: *whoever has the highest log index wins.*
This step builds exactly that rule — and then deliberately watches it hand you **two leaders** under a
partition. The goal is to feel the bug, not to fix it.

## Teach the mechanisms
- **Election trigger.** The election timeout you built is the trigger: when a follower hears nothing,
  it stops waiting and becomes a candidate.
- **The naive rule.** A candidate asks the peers it can currently reach for their last log index,
  compares, and if its own is highest (among those it can see) it declares itself leader.
- **Why this splits the brain.** Under a partition each side sees only its own members. Each side
  runs the rule locally, each finds a local "highest," and each crowns a leader. Two leaders, both
  certain, both accepting writes. The rule's flaw is that "highest among who I can reach" is a
  **local** decision dressed up as a global one.

## Spine  (the learner types `workspace/election.rb`, ~25 lines)
On election timeout, start an election: gather last-index from reachable peers over the Link, and
declare self leader if your last index is the highest you can see. No quorum, no vote counting —
that's the point. Reuse the timeout from the heartbeat step and the Link so you can partition.

**Read first:** `docs/wire-protocol-cheatsheet.md` (a "what's your last index?" query and its reply).

## Agent role
- `[explain]` Make sure the learner understands this step is meant to *reproduce* a failure, so "it
  elected two leaders" is success here. Point at how the timeout starts the election.
- `[review]` Does the candidate decide purely on reachable peers (no majority test)? Does a partition
  actually isolate the two sides on the Link? Is the double-leader outcome observable in the logs?

## Gotchas
- Expecting it to be correct — it is *supposed* to produce split-brain; don't "fix" it early.
- Ties when two nodes share the same last index — decide something, but note it's arbitrary.
- Treating an unreachable peer as if it agreed, instead of simply invisible.

## Success check
Run 3 nodes. Partition them 2:1 on the Link. Trigger elections (let the timeouts fire). Observe that
**both** sides elect a leader — two leaders at once. Capture it in the logs; that divergence is the
demonstration.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Point at the exact step of your naive rule that let the minority side crown a leader. What did that
side *not* know?

**Quiz topic 2 — Design:**
What single piece of information is the rule missing that would have stopped one of the two sides from
electing?

**Quiz topic 3 — Reflect:**
Why is "the highest index among the peers I can reach" not enough to safely claim leadership of the
whole cluster?

## Next step
There is one logical next step. The fix is to stop letting a node crown itself on local information —
and to require agreement from more than half the cluster. Then point them to **Step 19** and run
`/replicant:next`.

Next: Majority-quorum election
