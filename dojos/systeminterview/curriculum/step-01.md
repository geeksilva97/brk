---
step: 1
title: Scoping the Problem
spine: workspace/scope.md
kind: interview
reference: -
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

**Read first:** `docs/webrtc-cheatsheet.md` (Key Numbers section) and `docs/capacity-cheatsheet.md` (The Estimation Framework)

## Spine  (the learner types `workspace/scope.md`, ~20-30 lines)

The candidate writes `workspace/scope.md` containing:
- A list of clarifying questions they would ask (and their assumed answers)
- Functional requirements (bullet list)
- Non-functional requirements (bullet list with numbers)
- Out-of-scope items
- Key assumptions

Rough size: 15-25 bullet points total.

## Agent role
- `[explain]` — Explain the 4-step framework and what each scoping category covers
- `[probe]` — Ask: "What questions would you ask before designing a video conferencing system?" Let them list questions first. Then ask follow-ups: "What about mobile?" "How many users at peak?" "Do you need recording?"
- `[scaffold]` — If they struggle, suggest categories: functional, non-functional, scale, out-of-scope. But let THEM fill in the items.
- `[review]` — Check that their scope includes: clarifying questions, functional + non-functional requirements, scale numbers, and out-of-scope items

## Gotchas

1. **Jumping to architecture without scoping** — the #1 mistake. Always scope first.
2. **Forgetting non-functional requirements** — latency is critical for video. Availability matters.
3. **Over-scoping** — trying to design every feature. Pick core features and state what's out of scope.
4. **Not asking about scale** — "design for 100 users" and "design for 100M users" are different problems.
5. **Assuming all clients are the same** — mobile has bandwidth constraints, screen size differences.

## Success check

Candidate has produced `workspace/scope.md` with:
- At least 5 clarifying questions (with assumed answers)
- Functional requirements listed
- Non-functional requirements with numbers (latency, availability)
- Clear out-of-scope section
- At least one scale-related number (DAU, concurrent users)

Verify by reading the file. If missing scale numbers, prompt: "How many users are we designing for?"

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