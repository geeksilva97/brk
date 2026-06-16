---
step: 5
title: "Capacity Planning & Estimation"
spine: workspace/capacity.md
kind: interview
reference: capacity-reference.md
---

# Step 5: Capacity Planning & Estimation

## Frame

Architecture without numbers is just a drawing. Back-of-the-envelope estimation turns "a lot of users" into "150 SFU servers, 200 TB storage, $50K/day bandwidth." This is where strong candidates separate from average ones.

## Teach the Mechanism

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
- WebRTC connection memory: ~10-50 KB per connection (varies by implementation)
- TURN relay: adds ~2-4 Mbps per relayed participant
- Recording: ~300 MB/hour per stream (compressed)

**Key ratios:**
- 1 SFU server ≈ 1 Gbps bandwidth capacity
- 1 signaling server ≈ 100K-1M concurrent WebSocket connections
- Peak concurrent ≈ 10-15% of DAU for video conferencing
- TURN usage ≈ 10-20% of participants

## Spine

The candidate creates `workspace/capacity.md` containing:
- All assumptions listed with numbers
- Per-second/per-minute rate calculations
- Bandwidth estimation: total and per-server
- Server count estimation: SFU, signaling, TURN, API
- Storage estimation: recordings, metadata
- Cost breakdown (approximate): bandwidth, servers, TURN relay

Rough size: 1 page of calculations with clear assumptions.

## Agent Role

[probe] — Ask the candidate to estimate:
- "How many concurrent users at peak for 5M DAU?"
- "What's the total bandwidth at peak?"
- "How many SFU servers do you need?"
- "What's the TURN bandwidth cost per month?"
- "How much storage for 1 month of recordings?"

Let THEM do the math. Only correct arithmetic errors.

[scaffold] — If they're stuck on where to start, suggest: "Start with DAU → concurrent users → bandwidth per user → total bandwidth → servers."

[review] — Check for:
- Clear assumptions (don't accept "a lot" — demand numbers)
- Correct unit conversions (Mbps vs MBps, etc.)
- Peak multiplier included
- TURN cost calculated (not just mentioned)
- Recording storage estimated

## Gotchas

1. **Confusing Mbps and MBps** — 2 Mbps = 0.25 MB/s. This 8× mistake breaks all estimates.
2. **Forgetting peak multiplier** — Average and peak are different. Peak QPS ≈ 2-3× average.
3. **Not calculating TURN** — It's the biggest cost after SFU bandwidth. Must be estimated.
4. **Overestimating server capacity** — A single SFU handles ~1 Gbps, not 10 Gbps. Real numbers matter.
5. **Forgetting signaling and API servers** — Media gets all the attention, but you still need hundreds of signaling and API servers.

## Success Check

Candidate has produced `workspace/capacity.md` with:
- Assumptions listed (DAU, concurrent %, bandwidth per stream, etc.)
- Concurrent user calculation with peak multiplier
- Total bandwidth calculation
- Server count for each component type
- TURN bandwidth and approximate cost
- Storage estimate for recordings

If TURN cost is missing: "What's the monthly bandwidth cost for TURN servers?"
If peak multiplier is missing: "Is traffic the same at 3 AM and 3 PM?"

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1–5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count. -->

**Question 1:** Why do interviewers want to see your math even when the exact numbers don't matter?
A good answer covers: Order-of-magnitude estimates are what interviewers want — 500 vs 530 servers doesn't change the design. The process matters more than precision. "Horizontal scaling" without numbers is hand-waving. Pick reasonable assumptions (2 Mbps HD, 10% peak) and calculate. Skipping estimation and saying "we scale" shows no depth.

**Question 2:** Why does a video conferencing system at 500K concurrent users need hundreds of servers?
A good answer covers: A 10-person SFU call uses ~180 Mbps on the server side. At 500K concurrent users, you need 150+ SFU servers just for media, plus signaling, TURN, and API servers. TURN handles 15% of users = 75K users × 2 Mbps = 150 Gbps — expensive. Even 10% of calls recorded × 300 MB/hour = significant storage and processing costs. You can't just say "a few servers."