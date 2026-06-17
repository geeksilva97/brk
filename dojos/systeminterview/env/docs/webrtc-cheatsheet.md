# WebRTC Fundamentals Cheatsheet

*Provided as a reference — you don't need to memorize these, but you should understand
the concepts well enough to reason about them in a design interview.*

## WebRTC Connection Lifecycle

1. **Signaling** — exchange connection parameters (SDP offer/answer) via a separate channel (WebSocket)
2. **ICE candidate gathering** — discover potential network paths (host, server-reflexive, relay)
3. **ICE connectivity check** — test paths in parallel, pick the best one
4. **DTLS handshake** — establish encryption over the selected path
5. **SRTP media flow** — audio/video packets flow over the encrypted channel
6. **DataChannel** (optional) — can be established for chat, screen share control, etc.

## Key Protocols

| Protocol | Layer | Purpose |
|----------|-------|---------|
| SDP | Signaling | Describe codecs, resolutions, media capabilities (text format, not a protocol) |
| ICE | Connectivity | Framework for finding the best network path between peers |
| STUN | NAT traversal | Help client discover its public IP address (~80-90% of users) |
| TURN | NAT traversal | Relay ALL media when direct connection fails (~10-20% of users) |
| DTLS | Security | Encryption handshake (like TLS but over UDP) |
| SRTP | Media | Encrypted real-time media transport |
| RTP | Media | Real-time media packet format (audio/video) |
| RTCP | Media | Media quality feedback and stats |

## Media Topologies

### Mesh (P2P)
- Every participant sends N-1 streams, receives N-1 streams
- No server needed (just signaling)
- Client upload: 2 Mbps × (N-1). At 10 participants: 18 Mbps upload per client
- Works for 2-4 participants. Breaks at 6+

### SFU (Selective Forwarding Unit)
- Each participant sends 1 stream to the SFU
- SFU forwards (selectively) each stream to all other participants
- Client upload: 2 Mbps (1 stream). Client download: 2 Mbps × (N-1)
- SFU server bandwidth: ~N × (N-1) × 2 Mbps per call
- Industry standard for group video (Jitsi, Google Meet, Daily)
- Does NOT decode/re-encode. Just forwards RTP packets

### MCU (Multipoint Control Unit)
- Decodes all incoming streams, composites into one, re-encodes
- Client upload: 2 Mbps (1 stream). Client download: 2 Mbps (1 composite stream)
- Server CPU: very high (decode + composite + encode for every participant)
- Used when bandwidth is extremely limited (old hardware, slow networks)
- NOT the same as SFU — MCU decodes and re-encodes; SFU just forwards

## Trickle ICE

Instead of waiting for all ICE candidates before connecting, send them as they're discovered.
Faster connection setup. Candidates can arrive out of order — need to handle this.

## Key Numbers for Interviews

| Metric | Value |
|--------|-------|
| HD video (720p) | ~2 Mbps per stream |
| Low quality video | ~300 Kbps per stream |
| 1080p video | ~4 Mbps per stream |
| Audio | ~100 Kbps per participant |
| Screen share | ~1-2 Mbps |
| WebRTC connection memory | ~10-50 KB per connection |
| TURN relay bandwidth | ~2-4 Mbps per relayed participant |
| Single SFU capacity | ~1 Gbps bandwidth |
| STUN coverage | ~80-90% of users |
| TURN needed for | ~10-20% of users (symmetric NAT) |

## Signaling Server Requirements

- Persistent WebSocket connection per client
- Room management: create, join, leave
- SDP offer/answer relay
- ICE candidate relay (trickle ICE)
- Presence broadcasting (who's in the meeting)
- Reconnection handling (client drops, reconnects, must resume call)
- Service discovery: assign clients to least-loaded signaling server