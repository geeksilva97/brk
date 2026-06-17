---
step: 7
title: "Wrap-Up & Self-Review"
spine: "-"
kind: demo
reference: -
---

# Step 7: Wrap-Up & Self-Review

## Frame

This is the final step — the interview wrap-up. The candidate summarizes their design, identifies bottlenecks, and discusses improvements. This is also where we run the evaluation against the ground truth.

## Teach the Mechanisms

The wrap-up should cover (from Xu's framework, Step 4):

1. **Bottleneck identification** — What's the weakest point in the system?
2. **What would you improve?** — With more time, what would you build differently?
3. **Error handling** — What happens when things fail?
4. **Summary** — 60-second recap of the entire design

**Common bottlenecks in video conferencing:**
- TURN bandwidth cost (biggest infrastructure expense after SFU)
- Single-region deployment (latency for remote users)
- Recording pipeline bottleneck (CPU-heavy transcoding)
- Signaling server failover (stateful connections can't easily migrate)
- SFU connection limits per server

**Read first:** `docs/ground-truth.md` (Key Trade-offs, Scoring Rubric)

## Spine

No new file to write. The candidate:
1. Gives a 60-second verbal summary of their entire design
2. Lists the top 3 bottlenecks they've identified
3. Names 3 improvements they'd make with more time
4. Says "I'm done"

Then the tutor runs the **evaluation** against the ground truth.

## Agent role
- `[probe]` — Ask: "Give me a 60-second summary of your design." "What's the biggest bottleneck in your system?" "What would you change if you had more time?" "How would you handle a signaling server failure mid-call?" "What's the biggest cost driver and how would you reduce it?"
- `[review]` — After the candidate says "I'm done," run the evaluation:

### Evaluation Process
1. Read all candidate files in `workspace/`
2. Compare against the ground truth in `docs/ground-truth.md`
3. Score on 6 dimensions (see below)
4. Write evaluation to `workspace/evaluation.md`

### Scoring Rubric

**1. Scope (15%)**
- Strong: Asked 5+ clarifying questions, identified functional & non-functional requirements, stated assumptions, defined out-of-scope
- Adequate: Asked 3+ questions, covered main requirements
- Weak: Jumped to architecture without scoping

**2. Architecture (30%)**
- Strong: Correct components (signaling, media, TURN, API, presence), proper data flows, protocol choices justified
- Adequate: Main components present, some flows described
- Weak: Missing signaling, missing TURN, CDN for live video, mesh for large groups

**3. Deep Dive (25%)**
- Strong: WebRTC signaling flow correct, media topology justified (SFU), NAT traversal addressed, reconnection handled
- Adequate: Signaling described, topology chosen but not deeply justified
- Weak: Can't describe SDP/ICE flow, mesh for 10+ users, no reconnection

**4. Estimation (15%)**
- Strong: Clear assumptions, correct bandwidth math, server counts calculated, TURN cost estimated
- Adequate: Some estimation, roughly correct numbers
- Weak: No estimation, or wildly wrong numbers

**5. Trade-offs (10%)**
- Strong: Articulated 4+ trade-offs with clear pros/cons, justified choices, identified own design weaknesses
- Adequate: Mentioned 2-3 trade-offs
- Weak: No trade-offs discussed, or "just scale horizontally"

**6. Communication (5%)**
- Strong: Clear structure, good time management, asked for feedback, summarized well
- Adequate: Organized, communicated decisions
- Weak: Disorganized, jumped around, couldn't summarize

## Gotchas

1. **Not identifying their own bottlenecks** — Shows lack of self-awareness about the design
2. **Saying "I'd add more servers" for everything** — Horizontal scaling isn't the answer to stateful services
3. **Forgetting the 60-second summary** — This is the last impression. Make it count.
4. **Not discussing error handling** — "What happens when X fails?" is always asked.

## Success check

Candidate has:
- Given a 60-second summary
- Identified 3+ bottlenecks
- Named 3+ improvements
- Said "I'm done"

Then the evaluation file is written to `workspace/evaluation.md`.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Why is saying "my design is solid, no major weaknesses" a red flag in an interview? What does it signal about engineering maturity?

**Quiz topic 2 — Design:**
How would you prioritize the bottlenecks you identified — which one would you fix first and why? What's the cost of not fixing it?

**Quiz topic 3 — Reflect:**
What's the one insight from this entire interview that changed how you think about system design? How would you approach the next interview differently?

## Next step

Congratulations — you've completed the System Design Interview dojo! Run `/systeminterview:status` to see your final evaluation and progress.