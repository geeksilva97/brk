---
step: 3
title: "Deep Dive: Signaling & WebRTC"
spine: workspace/signaling.md
kind: design
reference: -
---

# Step 3: Deep Dive — Signaling & WebRTC

## Frame

The high-level architecture has boxes and arrows. Now zoom into the most critical flow: how two peers establish a real-time connection. This is the signaling dance — offer, answer, ICE candidates — and getting it wrong means no video call at all.

## Teach the Mechanisms

**WebRTC connection lifecycle:**

1. Caller creates an **SDP offer** (describes codecs, resolutions, media capabilities)
2. Offer is sent through **signaling server** to callee
3. Callee creates an **SDP answer** and sends it back
4. Both sides exchange **ICE candidates** (potential network paths: host, server-reflexive, relay)
5. ICE connectivity check finds the best path
6. **DTLS** handshake establishes encryption
7. **SRTP** media flows (audio/video)
8. **DataChannel** can also be established (for chat, screen share control)

**Key concepts:**
- **SDP (Session Description Protocol)**: Text blob describing what the peer can do (codecs, resolutions, ICE credentials). NOT a protocol — it's a format.
- **ICE (Interactive Connectivity Establishment)**: Framework for finding the best network path. Tries host (local), server-reflexive (STUN-discovered), and relay (TURN) candidates.
- **Trickle ICE**: Instead of waiting for all candidates, send them as discovered. Faster connection setup.

**Signaling server requirements:**
- Persistent WebSocket connection per client
- Room management: create, join, leave
- Must handle reconnect (client drops, reconnects, must resume call)
- Must broadcast presence to all participants in room
- Service discovery: assign clients to least-loaded signaling server

**Read first:** `docs/webrtc-cheatsheet.md` (WebRTC Connection Lifecycle, Key Protocols, Trickle ICE)

## GIVEN black box
The WebRTC fundamentals cheatsheet (`docs/webrtc-cheatsheet.md`) is provided — the protocol details (SDP, ICE, DTLS order) are given. You don't need to derive them; use them as building blocks for your signaling flow.

## Spine  (the learner types `workspace/signaling.md`, ~30-40 lines)

The candidate creates `workspace/signaling.md` containing:
- Complete signaling flow (step by step, numbered)
- What happens when: user A calls user B, user C joins existing call, user A loses connection
- ICE candidate exchange sequence
- Signaling server responsibilities list
- Reconnection handling

Rough size: 15-25 numbered steps + 5-8 responsibilities.

## Agent role
- `[explain]` — Walk through the WebRTC connection lifecycle and explain what each step accomplishes
- `[probe]` — Ask the candidate to walk through the signaling flow step by step. Then: "What happens if user A's SDP offer reaches user B before B is connected?" "What if ICE candidates arrive after the media starts?"
- `[scaffold]` — If stuck, remind them of the order: SDP offer → SDP answer → ICE candidates → DTLS → media. Ask what each step accomplishes.
- `[review]` — Check for correct SDP offer/answer order, ICE candidate exchange (must happen after SDP), room management (join/leave broadcasting), reconnection handling

## Gotchas

1. **Signaling is not media** — Signaling sets up the connection; media flows separately. Confusing these is a fundamental error.
2. **ICE candidates can arrive out of order** — Need trickle ICE or buffer candidates until SDP is set.
3. **Reconnection is hard** — When a client drops, how does the room know? How does the client resume? Need heartbeats and reconnect logic.
4. **Third participant changes topology** — Adding user C to a 1:1 call may switch from P2P mesh to SFU. This topology change must be signaled.
5. **SDP is not renegotiated lightly** — Adding/removing streams (mute, screen share) uses SDP renegotiation, which is error-prone.

## Success check

Candidate has produced `workspace/signaling.md` with:
- Numbered signaling flow (offer → answer → ICE → DTLS → media)
- Room join/leave flow
- At least one reconnection scenario handled
- ICE candidate exchange described
- Signaling server responsibilities listed

If reconnection is missing: "What happens when user A drops and reconnects 5 seconds later?"
If ICE is vague: "How do the peers discover each other's network addresses?"

The learner must explain *why* media can't flow before the offer/answer exchange before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
What does SDP negotiate, and why can't media flow before the offer/answer exchange completes? What breaks if you skip it?

**Quiz topic 2 — Design:**
How does ICE find a network path between two peers, and why isn't STUN enough? What does each candidate type (host, srflx, relay) represent?

**Quiz topic 3 — Reflect:**
Why can't a WebRTC client just reconnect after dropping, and what does the system need to handle? What's the insight that makes reconnection a deliberate design problem, not an automatic recovery?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 4** and run `/systeminterview:next`.