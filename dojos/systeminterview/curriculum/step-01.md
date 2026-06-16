---
step: 1
title: Scoping the Problem
spine: workspace/scope.md
kind: interview
reference: scope-reference.md
---

# Step 1: Scoping the Problem

## Frame

Every system design interview starts the same way: you're given a vague prompt like "Design Google Meet." Your first job isn't to draw boxes — it's to ask questions. The quality of your design depends on the quality of your requirements.

## Teach the Mechanism

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

## Spine

The candidate writes `workspace/scope.md` containing:
- A list of clarifying questions they would ask (and their assumed answers)
- Functional requirements (bullet list)
- Non-functional requirements (bullet list with numbers)
- Out-of-scope items
- Key assumptions

Rough size: 15-25 bullet points total.

## Agent Role

[probe] — Ask the candidate: "What questions would you ask before designing a video conferencing system?" Let them list questions first. Then ask follow-ups:
- "What about mobile?" (if they only mention web)
- "How many users at peak?" (if they don't mention scale)
- "What about users behind corporate firewalls?" (if they don't mention NAT)
- "Do you need recording?" (if they don't mention it)

[scaffold] — If they struggle, suggest categories: functional, non-functional, scale, out-of-scope. But let THEM fill in the items.

## Gotchas

1. **Jumping to architecture without scoping** — the #1 mistake. Always scope first.
2. **Forgetting non-functional requirements** — latency is critical for video. Availability matters.
3. **Over-scoping** — trying to design every feature. Pick core features and state what's out of scope.
4. **Not asking about scale** — "design for 100 users" and "design for 100M users" are different problems.
5. **Assuming all clients are the same** — mobile has bandwidth constraints, screen size differences.

## Success Check

Candidate has produced `workspace/scope.md` with:
- At least 5 clarifying questions (with assumed answers)
- Functional requirements listed
- Non-functional requirements with numbers (latency, availability)
- Clear out-of-scope section
- At least one scale-related number (DAU, concurrent users)

Verify by reading the file. If missing scale numbers, prompt: "How many users are we designing for?"

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1–5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count. -->

**Question 1:** Why do good scoping questions need to cover more than just features?
A good answer covers: functional requirements AND non-functional constraints (latency, availability) AND scale. The interviewer won't give you requirements — you drive scoping by asking. Scope down and state what's out of scope.

**Question 2:** Why does scale determine whether you need load balancers, sharding, or multi-region?
A good answer covers: 100 users vs 100M users = fundamentally different architectures. Scale is a first-class requirement, not an afterthought. Different scales require different architectural choices. DAU alone isn't enough — you need concurrent users, peak factor, and call duration. P2P works at small scale; SFU/MCU is needed at larger scale.

**Question 3:** Why can't real-time video use the same infrastructure as YouTube?
A good answer covers: YouTube can buffer; Meet must be real-time (<300ms end-to-end latency). CDN is for recorded content, not live streams. A few seconds of latency breaks conversation. Real-time requires edge deployment, not CDN caching.