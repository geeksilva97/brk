---
step: 4
title: "Deep Dive: Media Servers & NAT Traversal"
spine: workspace/media-servers.md
kind: design
reference: media-servers-reference.md
---

# Step 4: Deep Dive — Media Servers & NAT Traversal

## Frame

For 1:1 calls, direct P2P (mesh) works fine. But group calls need a media server. The choice between SFU, MCU, and mesh determines your scalability, bandwidth costs, and client CPU requirements. This is the heart of any video conferencing system.

## Teach the Mechanism

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
- Simpler client but very expensive server

**NAT Traversal (the 10-20% problem):**
- **STUN** (Session Traversal Utilities for NAT): Helps client discover its public IP. Free/cheap. Works for ~80-90% of users.
- **TURN** (Traversal Using Relays around NAT): Relays ALL media through a server when direct connection fails. Expensive (bandwidth). Needed for ~10-20% of users (symmetric NAT, corporate firewalls).
- TURN cost calculation: If 500K concurrent users and 15% need TURN, that's 75K users × 2 Mbps = 150 Gbps of TURN bandwidth.

## Spine

The candidate creates `workspace/media-servers.md` containing:
- Comparison table: Mesh vs SFU vs MCU (bandwidth per client, server cost, scalability limit)
- Their chosen topology with justification
- NAT traversal strategy (STUN + TURN)
- Bandwidth estimation for: 1:1 call, 4-person call, 10-person call
- TURN cost estimation

Rough size: 1 comparison table + 1-2 paragraphs of justification + calculations.

## Agent Role

[probe] — Ask the candidate:
- "Walk me through what happens when 10 people join a meeting. How many streams is each client handling?"
- "What happens when user 11 joins? Does anything change architecturally?"
- "How much bandwidth does your SFU need at peak?"
- "What percentage of your users will need TURN? What's the cost?"

[scaffold] — If they can't decide between SFU and MCU, ask them to compare: "If you had to choose between more server CPU (MCU) or more server bandwidth (SFU), which is cheaper?"

[review] — Check for:
- Correct bandwidth math (common error: forgetting upload vs download)
- TURN included with cost estimate
- Clear topology choice with justification
- Scalability limit identified (when to add more SFU servers)

## Gotchas

1. **SFU bandwidth math** — The SFU forwards N-1 copies of each stream. Total SFU bandwidth = Σ(streams × subscribers). Not just N × 2 Mbps.
2. **TURN is expensive** — Many candidates include TURN but don't calculate the bandwidth cost. At scale, TURN bandwidth is one of the biggest infrastructure costs.
3. **Confusing SFU and MCU** — SFU forwards encoded packets. MCU decodes, composites, re-encodes. These are fundamentally different.
4. **Forgetting about SFU scalability** — A single SFU handles ~1 Gbps. Need load balancing and SFU assignment for large meetings.
5. **Not handling topology change** — When a 1:1 call becomes 3 participants, it must switch from mesh to SFU. This transition needs signaling.

## Success Check

Candidate has produced `workspace/media-servers.md` with:
- Mesh vs SFU vs MCU comparison with bandwidth numbers
- Chosen topology with justification
- NAT traversal strategy (STUN + TURN)
- TURN cost estimate (users × percentage × bandwidth)
- Awareness that topology may change (mesh → SFU at 3+ participants)

If TURN is missing: "What happens when a user behind a corporate firewall tries to join?"
If bandwidth math is wrong: "Let's walk through a 4-person call. How many streams does the SFU forward?"

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1–5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count. -->

**Question 1:** Why does mesh topology break at 6+ participants, and when would you choose MCU over SFU?
A good answer covers: Mesh has each client uploading N-1 streams — at 10 users that's 18 Mbps per client, exceeding most home upload speeds. SFU reduces client upload to 1 stream but server bandwidth is still high (forwards N-1 copies). MCU saves client bandwidth (1 composite stream) but server cost is astronomical (decode+composite+encode for every stream combination). The choice depends on use case — SFU is industry standard for group video; MCU is for extremely bandwidth-limited clients.

**Question 2:** Why can 10-20% of users not join calls without TURN, and how do you estimate its cost?
A good answer covers: Users behind symmetric NAT (common in corporate networks) can't establish direct P2P connections — STUN only helps discover public IPs. TURN relays all media for those users, and at scale this is a major cost. At 500K concurrent users with 15% needing TURN, that's 75K users × 2 Mbps = 150 Gbps of relay bandwidth. TURN bandwidth can exceed all other server costs.

**Question 3:** Why can't you just add more SFU servers when you run out of capacity?
A good answer covers: A single SFU holds active WebRTC connections — they're stateful, not stateless. You need service discovery (like Zookeeper) to assign clients to the right server. You can't arbitrarily rebalance connections mid-call. At 500K concurrent users, you need hundreds of SFU servers with intelligent assignment.