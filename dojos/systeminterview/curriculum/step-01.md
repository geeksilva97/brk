---
step: 1
title: Scoping the Problem
kind: interview
---

# Step 1: Scoping the Problem

## Frame

Every system design interview starts the same way: you're given a vague prompt like "Design Google Meet." Your first job isn't to draw boxes — it's to ask questions. The quality of your design depends on the quality of your requirements.

## Teach the Mechanisms

The 4-step framework (from Xu's book):

1. **Understand the problem and establish design scope** ← this step
2. Propose high-level design and get buy-in
3. Design deep dive
4. Wrap up

Key scoping questions for video conferencing:

**Functional requirements:**
- 1:1 calls, group calls, or both?
- Maximum participants per call?
- Screen sharing? Recording? Chat during call?
- Mute/unmute, camera on/off?

**Non-functional requirements:**
- Latency target (real-time needs <300ms)
- Availability (is a 5-minute outage acceptable?)
- Reliability (what happens when a participant drops?)

**Scale:**
- DAU (daily active users)?
- Concurrent users at peak?
- Average call duration?
- Geographic distribution?

**Out of scope (usually):**
- End-to-end encryption (mention it, but say you'll note it for later)
- Legacy browser support

**Reference:** `curriculum/reference/webrtc-cheatsheet.md` (Key Numbers section) and `curriculum/reference/capacity-cheatsheet.md` (The Estimation Framework)

## Conversation Flow

The learner discusses their scoping verbally. Guide them through:

1. **Ask them to list their clarifying questions** — "What questions would you ask before designing a video conferencing system?"
2. **Probe categories they miss** — If they skip non-functional: "What about latency?" If they skip scale: "How many users?"
3. **Push for numbers** — "You said 'a lot of users' — what's a lot? 10K? 10M?"
4. **Have them state out-of-scope items** — "What are you NOT designing?"
5. **Summarize** — "So you're designing for 5M DAU, 500K concurrent, with recording and screen sharing, under 300ms latency, excluding E2EE. Right?"

## Agent role
- `[explain]` — Explain the 4-step framework and what each scoping category covers
- `[probe]` — Ask: "What questions would you ask?" Then follow-ups: "What about mobile?" "How many users at peak?" "Do you need recording?"
- `[scaffold]` — If they struggle, suggest categories: functional, non-functional, scale, out-of-scope. But let THEM fill in the items.

## Gotchas

1. **Jumping to architecture without scoping** — the #1 mistake. Always scope first.
2. **Forgetting non-functional requirements** — latency is critical for video. Availability matters.
3. **Over-scoping** — trying to design every feature. Pick core features and state what's out of scope.
4. **Not asking about scale** — "design for 100 users" and "design for 100M users" are different problems.
5. **Assuming all clients are the same** — mobile has bandwidth constraints, screen size differences.

## Success check

The learner has verbally demonstrated:
- At least 5 clarifying questions (with assumed answers)
- Functional requirements listed
- Non-functional requirements with numbers (latency, availability)
- Clear out-of-scope section
- At least one scale-related number (DAU, concurrent users)

If missing scale numbers: "How many users are we designing for?"
If missing non-functional: "What latency target does real-time video need?"

The learner must explain *why* scoping comes before architecture before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Why does skipping scoping lead to architectures that solve the wrong problem? What breaks when you design without numbers?

**Quiz topic 2 — Design:**
Why do non-functional requirements (latency, availability) dictate architectural choices as much as features do? What's different about designing for 100 users vs 100M?

**Quiz topic 3 — Reflect:**
Why can't real-time video use the same infrastructure as YouTube (CDNs, buffering)? What's the one insight that makes scoping the most important 5 minutes of the interview?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 2** and run `/systeminterview:next`.