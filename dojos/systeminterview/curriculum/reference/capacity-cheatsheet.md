# Capacity Estimation Cheatsheet

*Provided as a reference — the process matters more than exact numbers. Use these
as starting assumptions and adjust based on your own scoping questions.*

## The Estimation Framework (from Alex Xu's System Design Interview)

1. **Start with assumptions** — Write them down. Label units. Round numbers.
2. **Calculate per-second/per-minute rates** — DAU × actions_per_day / 86400 = QPS
3. **Estimate storage** — data_per_day × retention = total storage
4. **Estimate bandwidth** — concurrent_users × stream_bandwidth = total bandwidth
5. **Estimate servers** — total_bandwidth / per_server_capacity = server count
6. **Add peak multiplier** — peak QPS ≈ 2-3× average QPS

## Video Conferencing Reference Numbers

| Metric | Value | Notes |
|--------|-------|-------|
| Video (HD 720p) | 2 Mbps | Per stream |
| Video (low quality) | 300 Kbps | Per stream |
| Audio | 100 Kbps | Per participant |
| Screen share | 1-2 Mbps | Per stream |
| Recording | ~300 MB/hr | Per stream, compressed |
| Peak concurrent users | 10-15% of DAU | For video conferencing |
| TURN usage | 10-20% | Of participants |
| Single SFU capacity | ~1 Gbps | Bandwidth-bound |
| Signaling connections | 100K-1M | Per server (WebSockets) |

## Unit Conversion (Gotcha Alert)

- 2 Mbps = 0.25 MB/s (divide by 8)
- 1 Gbps = 125 MB/s
- Always check: are you computing in bits or bytes?

## Example: Google Meet at 5M DAU

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
- Total SFU bandwidth: 125K × 32 Mbps ≈ 4 Tbps (aggressive)
- More realistic: ~1 Tbps total → ~1,000 SFU servers

### TURN
- 15% of 500K = 75K users via TURN
- 75K × 2 Mbps = 150 Gbps TURN bandwidth
- Cost at $0.05/GB: 150 Gbps × 3600 s × $0.05/GB ≈ $30K/hour at peak

### Signaling
- 500K concurrent WebSocket connections
- ~100-500 connections per server (stateful WebSockets)
- ~1,000-5,000 signaling servers

### Storage
- 10% of calls recorded
- 50K calls × 30 min × 300 MB/hr = 7.5 TB/day
- 90-day retention: 675 TB

### Server Summary (at peak)
- SFU: ~1,000-4,000 servers
- Signaling: ~1,000-5,000 servers
- TURN: ~150-300 servers (bandwidth-bound)
- API: ~50-100 servers (stateless, easy to scale)
- Recording workers: ~100-500 servers
- Database: ~10-20 nodes (with replicas)

## Key Trade-offs Quick Reference

| Trade-off | Options | Typical Choice |
|-----------|---------|----------------|
| Media topology | SFU vs MCU vs Mesh | SFU for groups, mesh for 1:1 |
| NAT traversal | STUN-only vs STUN+TURN | STUN+TURN (can't exclude 10-20%) |
| Small call handling | Mesh for 1:1 vs Always SFU | Hybrid (mesh for 1:1, SFU for 3+) |
| Recording | Composed layout vs Separate streams | Separate streams (flexible post-processing) |
| Multi-region | Nearest SFU vs Hub region | 3-5 regional clusters + GeoDNS |
| Recording pipeline | Inline vs Async | Async (never block media path) |