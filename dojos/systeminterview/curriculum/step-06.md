---
step: 6
title: "Recording, Multi-Region & Trade-offs"
spine: workspace/tradeoffs.md
kind: design
reference: -
---

# Step 6: Recording, Multi-Region & Trade-offs

## Frame

You have a working architecture for a single region. Now make it production-ready: add recording, deploy globally, and justify your trade-offs. This is where you show engineering maturity — every choice has a cost, and you need to articulate why you chose what you chose.

## Teach the Mechanisms

**Recording pipeline:**
- WebRTC stream → media server → recording service → transcoding pipeline → blob storage → CDN
- Recording is async: media server mixes selected streams, writes to chunked files (e.g., WebM segments)
- Transcoding pipeline (DAG model from YouTube chapter): split by GOP, encode multiple resolutions, generate thumbnails
- Storage: blob store (S3/GCS) for recordings, metadata DB for search/browsing
- CDN for replay only (NOT for live video)

**Multi-region deployment:**
- Route users to nearest region (GeoDNS, anycast)
- Signaling servers are stateful → can't easily migrate connections → route before connecting
- Media servers are stateful → same → route to nearest SFU
- For cross-region meetings: one participant may connect to a remote SFU → higher latency
- Alternative: SFU cascading (local SFU → backbone → remote SFU) for cross-region calls

**Key trade-offs to discuss:**

1. **SFU vs MCU**: SFU uses more bandwidth, less CPU. MCU uses less bandwidth, more CPU. SFU is industry standard.
2. **STUN-only vs STUN+TURN**: STUN-only is cheaper but excludes 10-20% of users. TURN is expensive but inclusive.
3. **Mesh for small calls vs always SFU**: Mesh for 1:1 saves server cost. Always-SFU simplifies code. Most production systems switch dynamically.
4. **Recording quality vs cost**: Record all streams separately (expensive, flexible) vs record composed layout (cheaper, less flexible).
5. **Multi-region latency vs cost**: More regions = lower latency but higher cost and data replication complexity.
6. **WebRTC vs custom protocol**: WebRTC is standard but complex. Custom protocols (like Zoom's) give more control but no browser interoperability.

**Read first:** `docs/capacity-cheatsheet.md` (Key Trade-offs Quick Reference)

## GIVEN black box
The capacity cheatsheet's trade-offs table (`docs/capacity-cheatsheet.md`) provides the options and typical choices. You don't need to derive these from scratch — use them as starting points for your own analysis.

## Spine  (the learner types `workspace/tradeoffs.md`, ~50-60 lines)

The candidate creates `workspace/tradeoffs.md` containing:
- Recording pipeline design (components and data flow)
- Multi-region deployment strategy
- 4-5 trade-offs with their analysis (pros/cons of each option, and their choice with justification)
- What they'd improve with more time (at least 3 items)

Rough size: 1 recording diagram + 1 multi-region diagram + 4-5 trade-off analyses.

## Agent role
- `[explain]` — Walk through the recording pipeline pattern and multi-region considerations
- `[probe]` — Ask: "How do you record a 10-person meeting? One file or multiple?" "What happens when a user in Brazil joins a meeting hosted in US-East?" "What's the biggest bottleneck in your system?"
- `[scaffold]` — If they haven't considered recording, suggest: "Think about how YouTube records and stores videos. What's different for live meeting recordings?"
- `[review]` — Check for recording pipeline with async processing (not blocking media path), multi-region strategy that considers stateful server placement, trade-offs articulated with clear pros/cons, self-critical analysis

## Gotchas

1. **Recording blocks media path** — Recording should be async. The media server sends a copy to a recording service, not inline.
2. **Multi-region stateful servers** — You can't just "deploy in 3 regions." Stateful servers (signaling, media) need careful routing.
3. **Cross-region latency** — A meeting with participants in US and Europe needs a strategy. SFU in one region = some participants have high latency.
4. **Forgetting consistency** — Meeting metadata (who's in the meeting, meeting history) needs to be consistent across regions.
5. **No trade-offs discussed** — Every design has weaknesses. Not identifying them shows lack of maturity.

## Success check

Candidate has produced `workspace/tradeoffs.md` with:
- Recording pipeline (async, not blocking media)
- Multi-region strategy (GeoDNS + regional SFU + routing)
- At least 4 trade-offs with analysis
- Self-identified bottlenecks and improvements
- Clear justification for each choice

If recording is inline: "What happens to the call if the recording service crashes?"
If multi-region is just "deploy everywhere": "How do you decide which SFU a user in São Paulo connects to?"

The learner must explain *why* every design choice has a trade-off and why "just scale horizontally" isn't enough before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Why must recording be async, and what happens if it blocks the media path? What breaks in a live call when the recording service goes down?

**Quiz topic 2 — Design:**
Why can't you just deploy stateful servers in multiple regions and load balance across them? What makes geographic placement critical for real-time video?

**Quiz topic 3 — Reflect:**
Why does "I'd just scale horizontally" show a lack of depth in a system design interview? What's the insight that separates strong candidates from average ones when discussing trade-offs?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 7** and run `/systeminterview:next`.