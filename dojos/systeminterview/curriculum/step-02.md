---
step: 2
title: High-Level Architecture
spine: workspace/architecture.md
kind: design
reference: -
---

# Step 2: High-Level Architecture

## Frame

You've scoped the problem. Now draw the blueprint. A video conferencing system has three distinct flows: signaling (setting up the call), media (the actual video/audio), and data (chat, screen share metadata). Each needs different infrastructure.

## Teach the Mechanisms

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

**From Xu's Chat System patterns:**
- Signaling servers are like chat servers — stateful, persistent connections
- Service discovery (like Zookeeper) assigns clients to least-loaded signaling server
- Presence servers track who's online / in the meeting
- Multi-device sync: user may join from phone + laptop

**Read first:** `docs/webrtc-cheatsheet.md` (Media Topologies section and Signaling Server Requirements)

## GIVEN black box
The WebRTC fundamentals cheatsheet (`docs/webrtc-cheatsheet.md`) is provided — you don't need to derive the protocols from scratch. Use it as reference when naming components and protocol choices.

## Spine  (the learner types `workspace/architecture.md`, ~40-50 lines)

The candidate creates `workspace/architecture.md` containing:
- A text-based architecture diagram showing all major components
- Data flow descriptions: "When user A joins a meeting..."
- Component responsibilities (1-2 sentences each)
- Protocol choices (WebSocket for signaling, WebRTC for media, HTTP for API)
- Brief note on why each component exists

Rough size: 1 diagram + 10-15 component descriptions.

## Agent role
- `[explain]` — Explain the three flows (signaling, media, data) and why each needs different infrastructure
- `[probe]` — Ask the candidate to draw their architecture. Then probe: "How does user A connect to user B?" "What happens when a user joins a meeting already in progress?" "How do you handle users behind restrictive firewalls?"
- `[scaffold]` — If they're stuck, suggest starting with three columns: "Client", "Signaling", "Media". Then fill in connections.
- `[review]` — Check their architecture for missing signaling server, missing TURN/STUN, missing presence service, HTTP polling instead of WebSocket, CDN used for live video

## Gotchas

1. **Missing signaling layer** — WebRTC needs a signaling channel (WebSocket, not HTTP) to exchange SDP and ICE candidates. Most candidates forget this.
2. **Mesh for everything** — P2P mesh doesn't scale past 4-6 participants. Every participant sends N-1 streams.
3. **Missing TURN** — ~10-20% of users are behind symmetric NAT and cannot connect directly. Without TURN, they can't join calls.
4. **CDN for live video** — CDN is for recorded content, not real-time media. This is a fundamental misunderstanding.
5. **Stateless everything** — Signaling and media servers are stateful. You can't just "add more" without considering connection migration.

## Success check

Candidate has produced `workspace/architecture.md` with:
- Architecture diagram showing: clients, signaling server, media server (SFU/MCU), TURN/STUN, API server, database, presence service
- Data flow described for at least: joining a meeting, leaving a meeting
- Protocol choices justified (WebSocket for signaling, WebRTC for media)
- TURN/STUN included with explanation
- No CDN for live video

If TURN is missing: "What about users behind corporate firewalls?"
If mesh is used for group calls: "What happens with 10 participants? How many streams per client?"

The learner must explain *why* signaling and media are separate channels before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Why does WebRTC need a separate signaling channel, and what breaks if you try to use HTTP polling for it? Why is WebSocket the right choice?

**Quiz topic 2 — Design:**
Why doesn't P2P mesh work for group calls, and what does an SFU do instead that's different from an MCU? What happens to client bandwidth at 10 participants with each topology?

**Quiz topic 3 — Reflect:**
Why can't ~10-20% of users connect without TURN, and what does that mean for infrastructure cost? What's the insight that makes this the most expensive component after SFU bandwidth?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 3** and run `/systeminterview:next`.