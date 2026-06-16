---
step: 3
title: "Deep Dive: Signaling & WebRTC"
spine: workspace/signaling.md
kind: design
reference: signaling-reference.md
---

# Step 3: Deep Dive — Signaling & WebRTC

## Frame

The high-level architecture has boxes and arrows. Now zoom into the most critical flow: how two peers establish a real-time connection. This is the signaling dance — offer, answer, ICE candidates — and getting it wrong means no video call at all.

## Teach the Mechanism

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

## Spine

The candidate creates `workspace/signaling.md` containing:
- Complete signaling flow (step by step, numbered)
- What happens when: user A calls user B, user C joins existing call, user A loses connection
- ICE candidate exchange sequence
- Signaling server responsibilities list
- Reconnection handling

Rough size: 15-25 numbered steps + 5-8 responsibilities.

## Agent Role

[probe] — Ask the candidate to walk through the signaling flow step by step. Then:
- "What happens if user A's SDP offer reaches user B before B is connected?"
- "What if ICE candidates arrive after the media starts?"
- "How does a third participant join an existing 1:1 call?"
- "What happens when a participant loses connection mid-call?"

[scaffold] — If stuck, remind them of the order: SDP offer → SDP answer → ICE candidates → DTLS → media. Ask what each step accomplishes.

[review] — Check for:
- Correct SDP offer/answer order
- ICE candidate exchange (must happen after SDP)
- Room management (join/leave broadcasting)
- Reconnection handling (this is where most designs fail)

## Gotchas

1. **Signaling is not media** — Signaling sets up the connection; media flows separately. Confusing these is a fundamental error.
2. **ICE candidates can arrive out of order** — Need trickle ICE or buffer candidates until SDP is set.
3. **Reconnection is hard** — When a client drops, how does the room know? How does the client resume? Need heartbeats and reconnect logic.
4. **Third participant changes topology** — Adding user C to a 1:1 call may switch from P2P mesh to SFU. This topology change must be signaled.
5. **SDP is not renegotiated lightly** — Adding/removing streams (mute, screen share) uses SDP renegotiation, which is error-prone. Some designs use separate WebRTC connections for screen share.

## Success Check

Candidate has produced `workspace/signaling.md` with:
- Numbered signaling flow (offer → answer → ICE → DTLS → media)
- Room join/leave flow
- At least one reconnection scenario handled
- ICE candidate exchange described
- Signaling server responsibilities listed

If reconnection is missing: "What happens when user A drops and reconnects 5 seconds later?"
If ICE is vague: "How do the peers discover each other's network addresses?"

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1–5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count. -->

**Question 1:** What does SDP negotiate, and why can't media flow before the offer/answer exchange?
A good answer covers: SDP describes what each peer can send/receive (codecs, resolutions, media capabilities) — it's the negotiation before the connection, not the media itself. The actual media flows on a separate channel after ICE/DTLS. Renegotiation is needed for adding/removing streams (screen share, new participants). While SDP can technically be sent over HTTP, WebSocket is used in practice because ICE candidates arrive incrementally and need real-time delivery.

**Question 2:** How does ICE find a network path between two peers, and why isn't STUN enough?
A good answer covers: ICE tries multiple candidate paths in parallel — host (local IP) first, then server-reflexive (STUN-discovered), then relay (TURN). The first working path wins. ICE is the framework; STUN is just one of its tools. Not all candidates must be gathered before connecting — trickle ICE sends them as discovered for faster setup. ICE connections aren't permanent — ICE restart can renegotiate if network conditions change.

**Question 3:** Why can't a WebRTC client just reconnect after dropping, and what does the system need to handle?
A good answer covers: WebRTC uses UDP (via DTLS), so application-level reconnection is needed — not TCP. A reconnecting client must re-signaling (SDP offer/answer again), and the room must know the client temporarily left. Without heartbeats, the server can't distinguish a slow connection from a dead one. Reconnection isn't automatic — it requires deliberate design for detection, re-signaling, and state recovery.