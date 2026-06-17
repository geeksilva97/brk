---
step: 5
title: "Capacity Planning & Estimation"
kind: interview
---

# Step 5: Capacity Planning & Estimation

## Frame

Architecture without numbers is just a drawing. Back-of-the-envelope estimation turns "a lot of users" into "150 SFU servers, 200 TB storage, $50K/day bandwidth." This is where strong candidates separate from average ones.

## Teach the Mechanisms

**The estimation framework (from Xu Ch.2):**

1. **Start with assumptions** — Write them down. Label units. Round numbers.
2. **Calculate per-second/per-minute rates** — DAU × actions_per_day / 86400 = QPS
3. **Estimate storage** — data_per_day × retention = total storage
4. **Estimate bandwidth** — concurrent_users × stream_bandwidth = total bandwidth
5. **Estimate servers** — total_bandwidth / per_server_capacity = server count
6. **Add peak multiplier** — peak QPS ≈ 2-3× average QPS

**Video conferencing specific numbers:**
- Video stream: ~2 Mbps (HD 720p), ~300 Kbps (low quality), ~4 Mbps (1080p)
- Audio stream: ~100 Kbps per participant
- Screen share: ~1-2 Mbps
- TURN relay: adds ~2-4 Mbps per relayed participant
- Recording: ~300 MB/hour per stream (compressed)

**Key ratios:**
- 1 SFU server ≈ 1 Gbps bandwidth capacity
- 1 signaling server ≈ 100K-1M concurrent WebSocket connections
- Peak concurrent ≈ 10-15% of DAU for video conferencing
- TURN usage ≈ 10-20% of participants

**Reference:** `curriculum/reference/capacity-cheatsheet.md` (The Estimation Framework, Video Conferencing Reference Numbers, Example: Google Meet at 5M DAU)

## GIVEN reference
The capacity estimation cheatsheet (`curriculum/reference/capacity-cheatsheet.md`) contains the reference numbers and the worked example at 5M DAU. Use it as a starting point.

## Conversation Flow

The learner works through estimation verbally. Guide them through:

1. **Start with assumptions** — "What numbers are you assuming? DAU? Concurrent percentage?"
2. **Walk through the math together** — "Okay, 5M DAU, 10% concurrent — how many concurrent users at peak?"
3. **Calculate bandwidth** — "Now how much total bandwidth? How many SFU servers?"
4. **Don't let them skip TURN** — "What's the TURN bandwidth? What's the cost?"
5. **Add storage** — "If 10% of calls are recorded, how much storage per day?"

## Agent role
- `[explain]` — Walk through the estimation framework and why each step matters
- `[probe]` — Ask: "How many concurrent users at peak for 5M DAU?" "What's the total bandwidth at peak?" "How many SFU servers?" "What's the TURN bandwidth cost per month?"
- `[scaffold]` — If stuck on where to start: "Start with DAU → concurrent users → bandwidth per user → total bandwidth → servers."

## Gotchas

1. **Confusing Mbps and MBps** — 2 Mbps = 0.25 MB/s. This 8× mistake breaks all estimates.
2. **Forgetting peak multiplier** — Average and peak are different. Peak QPS ≈ 2-3× average.
3. **Not calculating TURN** — It's the biggest cost after SFU bandwidth. Must be estimated.
4. **Overestimating server capacity** — A single SFU handles ~1 Gbps, not 10 Gbps.
5. **Forgetting signaling and API servers** — Media gets all the attention, but you still need hundreds of signaling and API servers.

## Success check

The learner has verbally demonstrated:
- Assumptions stated (DAU, concurrent %, bandwidth per stream, etc.)
- Concurrent user calculation with peak multiplier
- Total bandwidth calculation
- Server count for each component type
- TURN bandwidth and approximate cost
- Storage estimate for recordings

If TURN cost is missing: "What's the monthly bandwidth cost for TURN servers?"
If peak multiplier is missing: "Is traffic the same at 3 AM and 3 PM?"

The learner must explain *why* showing the process matters more than exact numbers before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Why do interviewers want to see your math even when the exact numbers don't matter?

**Quiz topic 2 — Design:**
Why does a video conferencing system at 500K concurrent users need hundreds of servers? Walk through what makes each component type expensive.

**Quiz topic 3 — Reflect:**
What's the one insight that makes back-of-the-envelope estimation the differentiator between strong candidates and average ones?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 6** and run `/systeminterview:next`.