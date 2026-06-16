---
step: 2
title: High-Level Architecture
spine: workspace/architecture.md
kind: design
reference: architecture-reference.md
---

# Step 2: High-Level Architecture

## Frame

You've scoped the problem. Now draw the blueprint. A video conferencing system has three distinct flows: signaling (setting up the call), media (the actual video/audio), and data (chat, screen share metadata). Each needs different infrastructure.

## Teach the Mechanism

Key components for video conferencing:

**Signaling flow:**
- Clients connect via WebSocket to signaling servers
- Signaling exchanges SDP offer/answer (WebRTC negotiation)
- ICE candidates are exchanged to find network paths
- Signaling servers are stateful (each client has a persistent WebSocket connection)

**Media flow:**
- WebRTC for real-time audio/video
- Direct peer-to-peer (mesh) for 1:1 calls
- Media server (SFU or MCU) for group calls
- STUN servers help clients discover their public IP
- TURN servers relay media when direct connection fails (symmetric NAT)

**Data/management flow:**
- API servers (stateless) for room management, user auth, history
- Database for user data, meeting metadata
- Presence service for "who's in the meeting"

**From Step 1 (Chat System patterns, Xu Ch.12):**
- Signaling servers are like chat servers — stateful, persistent connections
- Service discovery (like Zookeeper) assigns clients to least-loaded signaling server
- Presence servers track who's online / in the meeting
- Multi-device sync: user may join from phone + laptop

## Spine

The candidate creates `workspace/architecture.md` containing:
- A text-based architecture diagram showing all major components
- Data flow descriptions: "When user A joins a meeting..."
- Component responsibilities (1-2 sentences each)
- Protocol choices (WebSocket for signaling, WebRTC for media, HTTP for API)
- Brief note on why each component exists

Rough size: 1 diagram + 10-15 component descriptions.

## Agent Role

[probe] — Ask the candidate to draw their architecture. Then probe:
- "How does user A connect to user B?" (signaling flow)
- "What happens when a user joins a meeting already in progress?" (room management)
- "How do you handle users behind restrictive firewalls?" (TURN)
- "Where do you store meeting metadata?" (database)

[scaffold] — If they're stuck, suggest starting with three columns: "Client", "Signaling", "Media". Then fill in connections.

[review] — Check their architecture for:
- Missing signaling server (common omission)
- Missing TURN/STUN (very common omission)
- Missing presence/room management service
- Using HTTP polling instead of WebSocket for signaling
- Confusing CDN with media server

## Gotchas

1. **Missing signaling layer** — WebRTC needs a signaling channel (WebSocket, not HTTP) to exchange SDP and ICE candidates. Most candidates forget this.
2. **Mesh for everything** — P2P mesh doesn't scale past 4-6 participants. Every participant sends N-1 streams.
3. **Missing TURN** — ~10-20% of users are behind symmetric NAT and cannot connect directly. Without TURN, they can't join calls.
4. **CDN for live video** — CDN is for recorded content, not real-time media. This is a fundamental misunderstanding.
5. **Stateless everything** — Signaling and media servers are stateful. You can't just "add more" without considering connection migration.

## Success Check

Candidate has produced `workspace/architecture.md` with:
- Architecture diagram showing: clients, signaling server, media server (SFU/MCU), TURN/STUN, API server, database, presence service
- Data flow described for at least: joining a meeting, leaving a meeting
- Protocol choices justified (WebSocket for signaling, WebRTC for media)
- TURN/STUN included with explanation
- No CDN for live video

If TURN is missing: "What about users behind corporate firewalls?"
If mesh is used for group calls: "What happens with 10 participants? How many streams per client?"
If signaling is missing: "How do the peers find each other?"

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1–5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count. -->

**Question 1:** Why does WebRTC need a separate signaling channel, and why is WebSocket the right choice?
A good answer covers: WebRTC requires signaling to exchange connection parameters (SDP) and network paths (ICE candidates) before media can flow. HTTP polling has too much latency for real-time call setup. Signaling and media are separate concerns — signaling manages connection setup, media handles the streams.

**Question 2:** Why doesn't P2P mesh work for group calls, and what does an SFU do instead?
A good answer covers: In mesh, each participant sends N-1 streams and receives N-1 streams, so bandwidth grows O(N²). At 10 participants, each client uploads 9 streams. An SFU receives each stream once and forwards it to all others — client upload drops to 1 stream. SFU reduces client upload but server bandwidth is still high (forwards N-1 copies). MCU is NOT the same as SFU — MCU decodes, composites, and re-encodes (very CPU-heavy on server), while SFU just forwards encoded packets.

**Question 3:** Why can't ~10-20% of users connect without TURN, and what does that mean for infrastructure cost?
A good answer covers: Users behind symmetric NAT (common in corporate networks) cannot establish direct P2P connections. STUN only helps discover public IPs (works for ~80-90%). TURN relays all media through a server for the remaining 10-20%, and this is expensive — TURN bandwidth is one of the biggest infrastructure costs in video conferencing.