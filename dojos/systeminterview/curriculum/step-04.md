---
step: 4
title: "Deep Dive: Media Servers & NAT Traversal"
kind: design
---

# Step 4: Deep Dive — Media Servers & NAT Traversal

## Frame

For 1:1 calls, direct P2P (mesh) works fine. But group calls need a media server. The choice between SFU, MCU, and mesh determines your scalability, bandwidth costs, and client CPU requirements. This is the heart of any video conferencing system.

## Teach the Mechanisms

**Three topologies:**

**Mesh (P2P):**
- Every participant sends N-1 streams and receives N-1 streams
- No server needed (just signaling)
- Client upload: 2 Mbps × (N-1). At 10 participants: 18 Mbps upload per client
- Works for 2-4 participants. Breaks at 6+.

**SFU (Selective Forwarding Unit):**
- Each participant sends 1 stream to the SFU
- SFU forwards (selectively) each stream to all other participants
- Client upload: 2 Mbps (1 stream). Client download: 2 Mbps × (N-1)
- SFU upload: 2 Mbps × N × (N-1). At 10 participants: 180 Mbps per SFU
- Industry standard for group video (Jitsi, Google Meet, Daily)
- Does NOT decode/re-encode. Just forwards RTP packets.

**MCU (Multipoint Control Unit):**
- Decodes all incoming streams, composites into one, re-encodes
- Client upload: 2 Mbps (1 stream). Client download: 2 Mbps (1 composite stream)
- Server CPU: very high (decode + composite + encode for every participant)

**NAT Traversal (the 10-20% problem):**
- **STUN** — Helps client discover its public IP. Free/cheap. Works for ~80-90% of users.
- **TURN** — Relays ALL media when direct connection fails. Expensive (bandwidth). Needed for ~10-20% of users.
- TURN cost: 500K concurrent × 15% × 2 Mbps = 150 Gbps TURN bandwidth.

**Reference:** `curriculum/reference/webrtc-cheatsheet.md` (Media Topologies) and `curriculum/reference/capacity-cheatsheet.md` (Example: Google Meet at 5M DAU)

## GIVEN reference
The WebRTC cheatsheet (`curriculum/reference/webrtc-cheatsheet.md`) provides the topology comparison and key numbers. The capacity cheatsheet (`curriculum/reference/capacity-cheatsheet.md`) provides the TURN cost estimation pattern.

## Conversation Flow

The learner explains their media topology choice and NAT traversal strategy verbally. Guide them through:

1. **Ask them to compare topologies** — "What are the options for handling media in a group call? Walk me through each."
2. **Push for bandwidth math** — "For a 10-person meeting with mesh, how many streams per client?" "With SFU?"
3. **Ask about NAT traversal** — "What percentage of users can't connect directly? What do you do for them?"
4. **Calculate TURN cost** — "At 500K concurrent users, what's your TURN bandwidth? What does that cost?"
5. **Challenge topology switching** — "What happens when a 1:1 call becomes a 3-person call?"

## Agent role
- `[explain]` — Walk through the three topologies and the NAT traversal problem
- `[probe]` — Ask: "Walk me through what happens when 10 people join a meeting. How many streams is each client handling?" "What's the TURN bandwidth cost?"
- `[scaffold]` — If they can't decide between SFU and MCU, ask: "If you had to choose between more server CPU (MCU) or more server bandwidth (SFU), which is cheaper?"

## Gotchas

1. **SFU bandwidth math** — The SFU forwards N-1 copies of each stream. Total SFU bandwidth = Σ(streams × subscribers). Not just N × 2 Mbps.
2. **TURN is expensive** — Many candidates include TURN but don't calculate the bandwidth cost. At scale, TURN bandwidth is one of the biggest infrastructure costs.
3. **Confusing SFU and MCU** — SFU forwards encoded packets. MCU decodes, composites, re-encodes. Fundamentally different.
4. **Forgetting about SFU scalability** — A single SFU handles ~1 Gbps. Need load balancing and SFU assignment for large meetings.
5. **Not handling topology change** — When a 1:1 call becomes 3 participants, it must switch from mesh to SFU.

## Success check

The learner has verbally demonstrated:
- Mesh vs SFU vs MCU comparison with bandwidth numbers
- Chosen topology with justification
- NAT traversal strategy (STUN + TURN)
- TURN cost estimate (users × percentage × bandwidth)
- Awareness that topology may change (mesh → SFU at 3+ participants)

If TURN is missing: "What happens when a user behind a corporate firewall tries to join?"
If bandwidth math is wrong: "Let's walk through a 4-person call. How many streams does the SFU forward?"

The learner must explain *why* SFU is the industry standard and how it differs from MCU before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Why does mesh topology break at 6+ participants, and what specifically happens to client bandwidth? When would you choose MCU over SFU?

**Quiz topic 2 — Design:**
Why can 10-20% of users not join calls without TURN, and how do you estimate its cost at scale?

**Quiz topic 3 — Reflect:**
Why can't you just add more SFU servers when you run out of capacity? What makes stateful servers fundamentally different from stateless ones?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 5** and run `/systeminterview:next`.