# System Design Interview — Google Meet: Ground Truth Reference

This document provides the complete reference design for evaluating candidate responses.

## Reference Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client (Browser/Mobile)                  │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────────────────┐ │
│  │ WebRTC   │  │ WebSocket    │  │ HTTP                     │ │
│  │ (Media)  │  │ (Signaling)  │  │ (API calls)              │ │
│  └────┬─────┘  └──────┬───────┘  └──────────┬───────────────┘ │
└───────┼───────────────┼──────────────────────┼─────────────────┘
        │               │                      │
        ▼               ▼                      ▼
┌───────────┐   ┌──────────────┐    ┌──────────────────┐
│ TURN/STUN │   │  Signaling   │    │   API Servers     │
│  Servers  │   │  Servers     │    │   (Stateless)     │
│           │   │  (Stateful)  │    │                    │
│  STUN:   │   │              │    │  ┌──────────────┐  │
│  discover │   │  - Room mgmt │    │  │ Auth/Profile │  │
│  public IP│   │  - SDP relay │    │  │ Meeting CRUD │  │
│           │   │  - ICE relay │    │  │ Recording API│  │
│  TURN:   │   │  - Presence  │    │  └──────────────┘  │
│  relay for│   │              │    │                    │
│  symmetric│   │  Service     │    │  Load Balancer    │
│  NAT      │   │  Discovery   │    │                    │
│           │   │  (Zookeeper) │    └────────┬───────────┘
│  ~10-20%  │   └──────┬───────┘             │
│  of users │          │                     │
└─────┬─────┘          │                     │
      │                │                     │
      ▼                ▼                     ▼
┌───────────┐   ┌──────────────┐    ┌──────────────────┐
│   Media    │   │  Presence    │    │   Database       │
│  Servers   │   │  Server      │    │                  │
│  (SFU)     │   │              │    │  - Users         │
│            │   │  - Who's in  │    │  - Meetings      │
│  Forward   │   │    meeting   │    │  - Recordings    │
│  encoded   │   │  - Heartbeat │    │                  │
│  RTP pkts  │   │              │    │  (PostgreSQL +   │
│            │   └──────────────┘    │   Redis cache)   │
│  ~1 Gbps   │                       └──────────────────┘
│  per server│
│            │
│  ┌────────┴────────────┐
│  │  Recording Service  │
│  │  (Async pipeline)   │
│  │                     │
│  │  Mix → Chunk →     │
│  │  Transcode → Store  │
│  └─────────────────────┘
└───────────┘
```

## Component Responsibilities

| Component | Protocol | Stateful? | Responsibility |
|-----------|----------|-----------|---------------|
| Client | WebRTC+WS+HTTP | N/A | UI, media capture/playback, signaling |
| Signaling Server | WebSocket | Yes | Room management, SDP relay, ICE candidate relay, presence |
| Media Server (SFU) | WebRTC (RTP/RTCP) | Yes | Forward encoded media streams, selective forwarding |
| TURN/STUN Server | STUN/TURN | No | NAT traversal: STUN discovers public IP, TURN relays media |
| API Servers | HTTP/HTTPS | No | Auth, meeting CRUD, recording management, user profile |
| Presence Server | WebSocket | Yes | Track who's online, heartbeat monitoring |
| Database | SQL | Yes | User data, meeting metadata, recording metadata |
| Service Discovery | - | Consistent | Assign clients to least-loaded signaling/media server |
| Recording Service | Internal | Mostly no | Async pipeline: receive stream, mix, transcode, store |
| Load Balancer | HTTP | No | Route API traffic, health checks |
| CDN | HTTPS | No | Serve recording replays (NOT live video) |

## Signaling Flow (Complete)

### 1:1 Call Setup
1. User A opens app → WebSocket connects to signaling server (via service discovery)
2. User A creates room → signaling server registers room, assigns room ID
3. User B joins room → WebSocket connects to signaling server (possibly different server)
4. User A creates SDP offer → sends to signaling server → relayed to User B
5. User B creates SDP answer → sends to signaling server → relayed to User A
6. Both exchange ICE candidates (trickle ICE) via signaling server
7. ICE connectivity check finds best path (host → srflx → relay)
8. DTLS handshake establishes encryption
9. SRTP media flows (audio/video)
10. DataChannel optionally opens (chat, screen share signaling)

### Group Call (3+ participants)
11. User C joins → signaling server notifies all participants
12. If switching from mesh to SFU: signaling server instructs all clients to connect to SFU
13. Each client sends 1 stream to SFU, receives N-1 streams from SFU
14. User C exchanges SDP offer/answer with SFU (not with each participant)

### Reconnection
15. Client detects connection loss (heartbeat timeout)
16. Signaling server marks client as "temporarily disconnected" (not "left")
17. Client reconnects WebSocket → signaling server sends room state
18. Client re-initiates ICE → new WebRTC connection established
19. If within timeout (e.g., 30s), client resumes without re-joining

## Capacity Estimation (Ground Truth)

### Assumptions
- 5M DAU
- 10% concurrent at peak = 500K concurrent users
- Average call: 4 participants, 30 minutes
- HD video: 2 Mbps per stream
- Audio: 100 Kbps per participant
- TURN usage: 15% of participants

### Bandwidth
- SFU inbound per call (4 participants): 4 × 2 Mbps = 8 Mbps
- SFU outbound per call (4 participants): 4 × 3 × 2 Mbps = 24 Mbps
- Total SFU per call: 32 Mbps
- Concurrent calls at peak: 500K / 4 = 125K calls
- Total SFU bandwidth: 125K × 32 Mbps ≈ 4 Tbps
- SFU servers needed: 4 Tbps / 1 Gbps per server ≈ 4,000 SFU servers

Wait, that's aggressive. Let me recalculate with more realistic numbers:
- Not all users in calls simultaneously at 4 participants
- More like: 500K concurrent × 2 Mbps avg (some audio-only) ≈ 1 Tbps total
- ~1,000 SFU servers

### TURN
- 15% of 500K = 75K users via TURN
- 75K × 2 Mbps = 150 Gbps TURN bandwidth
- Cost at $0.05/GB: 150 Gbps × 3600 s × $0.05/GB ≈ $30K/hour at peak

### Signaling
- 500K concurrent WebSocket connections
- ~100-500 connections per server (realistic for stateful WebSockets)
- ~1,000-5,000 signaling servers
- Messages: ~10-20 per call setup, ~1/heartbeat (5s), ~1/event

### Storage
- Recording: 10% of calls recorded
- 50K calls × 30 min × 300 MB/hr = 7.5 TB/day
- 90-day retention: 675 TB
- Metadata: negligible compared to video

### Server Summary (at peak)
- SFU: ~1,000-4,000 servers
- Signaling: ~1,000-5,000 servers
- TURN: ~150-300 servers (bandwidth-bound)
- API: ~50-100 servers (stateless, easy to scale)
- Recording workers: ~100-500 servers
- Database: ~10-20 nodes (with replicas)

## Key Trade-offs

### 1. SFU vs MCU
| | SFU | MCU |
|---|---|---|
| Client bandwidth | High (N-1 downloads) | Low (1 download) |
| Server CPU | Low (forward only) | Very high (decode+composite+encode) |
| Server bandwidth | Very high (N × N-1 forwards) | Low (N streams in, N out) |
| Scalability | Better (add more SFUs) | Limited (CPU-bound) |
| Industry standard | ✅ (Jitsi, Meet, Daily) | ❌ (legacy, expensive) |
| **Choice: SFU** | | |

### 2. Mesh for Small Calls vs Always-SFU
| | Mesh for 1:1 | Always SFU |
|---|---|---|
| Server cost for 1:1 | Zero | 1 SFU per call |
| Latency for 1:1 | Lower (direct) | Slightly higher |
| Code complexity | High (topology switch) | Low (one path) |
| **Choice: Hybrid** — mesh for 1:1/1:2, SFU for 3+ | | |

### 3. STUN-only vs STUN+TURN
| | STUN only | STUN + TURN |
|---|---|---|
| User coverage | ~80-90% | ~100% |
| Infrastructure cost | Low | High (bandwidth) |
| **Choice: STUN + TURN** — can't exclude 10-20% of users | | |

### 4. Recording: Composed vs Separate Streams
| | Composed layout | Separate streams |
|---|---|---|
| Storage cost | Low (1 file) | High (N files) |
| Post-processing flexibility | Low | High (rearrange, crop) |
| Server CPU | Medium (1 composite) | Medium (N recordings) |
| **Choice: Separate streams + composed later** | | |

### 5. Multi-region: Nearest SFU vs Hub
| | Nearest SFU | Hub region |
|---|---|---|
| Latency | Low for locals | High for remote users |
| Cross-region call quality | Needs SFU cascading | All go to hub |
| Complexity | High (routing, cascading) | Low (one region) |
| **Choice: 3-5 regional SFU clusters + GeoDNS** | | |

## Scoring Rubric

### Strong Hire (5/6 dimensions strong)
- Asked 5+ scoping questions, defined clear requirements
- Architecture includes signaling, SFU, TURN, presence, API
- Deep dive on WebRTC signaling, SFU topology, NAT traversal
- Solid estimation with assumptions and math
- Articulated 4+ trade-offs with clear justifications
- Clear 60-second summary, identified own bottlenecks

### Hire (4/6 dimensions adequate)
- Asked 3+ scoping questions
- Main architecture components present (may miss TURN or presence)
- Signaling flow described, topology chosen
- Some estimation (may be rough)
- 2-3 trade-offs mentioned
- Organized communication

### No Hire (3+ dimensions weak)
- Jumped to architecture without scoping
- Missing signaling or TURN
- Mesh for 10+ users or no reconnection handling
- No estimation or wildly wrong numbers
- No trade-offs discussed
- Disorganized, couldn't summarize