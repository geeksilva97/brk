---
step: 4
title: "Deep Dive: Media Servers & NAT Traversal"
spine: workspace/media-servers.md
kind: design
reference: -
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
- Used when bandwidth is extremely limited (old hardware, slow networks)

**NAT Traversal (the 10-20% problem):**
- **STUN** (Session Traversal Utilities for NAT): Helps client discover its public IP. Free/cheap. Works for ~80-90% of users.
- **TURN** (Traversal Using Relays around NAT): Relays ALL media through a server when direct connection fails. Expensive (bandwidth). Needed for ~10-20% of users (symmetric NAT, corporate firewalls).
- TURN cost calculation: If 500K concurrent users and 15% need TURN, that's 75K users × 2 Mbps = 150 Gbps of TURN bandwidth.

**Read first:** `docs/webrtc-cheatsheet.md` (Media Topologies) and `docs/capacity-cheatsheet.md` (Example: Google Meet at 5M DAU)

## GIVEN black box
The WebRTC cheatsheet (`docs/webrtc-cheatsheet.md`) provides the topology comparison and key numbers. The capacity cheatsheet (`docs/capacity-cheatsheet.md`) provides the TURN cost estimation pattern. You don't need to derive these numbers — use them as starting assumptions and adjust.

## Spine  (the learner types `workspace/media-servers.md`, ~30-40 lines)

The candidate creates `workspace/media-servers.md` containing:
- Comparison table: Mesh vs SFU vs MCU (bandwidth per client, server cost, scalability limit)
- Their chosen topology with justification
- NAT traversal strategy (STUN + TURN)
- Bandwidth estimation for: 1:1 call, 4-person call, 10-person call
- TURN cost estimation

Rough size: 1 comparison table + 1-2 paragraphs of justification + calculations.

## Agent role
- `[explain]` — Walk through the three topologies and the NAT traversal problem
- `[probe]` — Ask: "Walk me through what happens when 10 people join a meeting. How many streams is each client handling?" "What percentage of your users will need TURN? What's the cost?"
- `[scaffold]` — If they can't decide between SFU and MCU, ask: "If you had to choose between more server CPU (MCU) or more server bandwidth (SFU), which is cheaper?"
- `[review]` — Check for correct bandwidth math (common error: forgetting upload vs download), TURN included with cost estimate, clear topology choice with justification, scalability limit identified

## Gotchas

1. **SFU bandwidth math** — The SFU forwards N-1 copies of each stream. Total SFU bandwidth = Σ(streams × subscribers). Not just N × 2 Mbps.
2. **TURN is expensive** — Many candidates include TURN but don't calculate the bandwidth cost. At scale, TURN bandwidth is one of the biggest infrastructure costs.
3. **Confusing SFU and MCU** — SFU forwards encoded packets. MCU decodes, composites, re-encodes. These are fundamentally different.
4. **Forgetting about SFU scalability** — A single SFU handles ~1 Gbps. Need load balancing and SFU assignment for large meetings.
5. **Not handling topology change** — When a 1:1 call becomes 3 participants, it must switch from mesh to SFU. This transition needs signaling.

## Success check

Candidate has produced `workspace/media-servers.md` with:
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
Why can 10-20% of users not join calls without TURN, and how do you estimate its cost at scale? What makes TURN one of the biggest infrastructure expenses?

**Quiz topic 3 — Reflect:**
Why can't you just add more SFU servers when you run out of capacity? What's the insight that makes stateful servers fundamentally different from stateless ones?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 5** and run `/systeminterview:next`.