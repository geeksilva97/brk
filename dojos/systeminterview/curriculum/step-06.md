---
step: 6
title: "Recording, Multi-Region & Trade-offs"
kind: design
---

# Step 6: Recording, Multi-Region & Trade-offs

## Frame

You have a working architecture for a single region. Now make it production-ready: add recording, deploy globally, and justify your trade-offs. This is where you show engineering maturity — every choice has a cost, and you need to articulate why you chose what you chose.

## Teach the Mechanisms

**Recording pipeline:**
- WebRTC stream → media server → recording service → transcoding pipeline → blob storage → CDN
- Recording is async: media server writes chunked files (e.g., WebM segments)
- Transcoding pipeline: split by GOP, encode multiple resolutions, generate thumbnails
- Storage: blob store (S3/GCS) for recordings, metadata DB for search/browsing
- CDN for replay only (NOT for live video)

**Multi-region deployment:**
- Route users to nearest region (GeoDNS, anycast)
- Signaling servers are stateful → route before connecting
- Media servers are stateful → route to nearest SFU
- For cross-region meetings: one participant may connect to a remote SFU → higher latency
- Alternative: SFU cascading (local SFU → backbone → remote SFU)

**Key trade-offs to discuss:**

1. **SFU vs MCU**: SFU uses more bandwidth, less CPU. MCU uses less bandwidth, more CPU.
2. **STUN-only vs STUN+TURN**: STUN-only is cheaper but excludes 10-20% of users.
3. **Mesh for small calls vs always SFU**: Mesh for 1:1 saves server cost. Most systems switch dynamically.
4. **Recording quality vs cost**: Separate streams (expensive, flexible) vs composed layout (cheaper, less flexible).
5. **Multi-region latency vs cost**: More regions = lower latency but higher cost.
6. **WebRTC vs custom protocol**: WebRTC is standard but complex. Custom protocols give more control but no browser interop.

**Reference:** `curriculum/reference/capacity-cheatsheet.md` (Key Trade-offs Quick Reference)

## GIVEN reference
The capacity cheatsheet's trade-offs table (`curriculum/reference/capacity-cheatsheet.md`) provides the options and typical choices.

## Conversation Flow

The learner discusses recording, multi-region, and trade-offs verbally. Guide them through:

1. **Ask about recording** — "How would you record a 10-person meeting? One file or multiple? What happens when the recording service crashes during a live call?"
2. **Ask about multi-region** — "Your users are in the US, Europe, and Asia. How do you deploy? What about cross-region meetings?"
3. **Ask about trade-offs** — "What are the biggest trade-offs you've made so far? What would you change with more time?"
4. **Challenge superficial answers** — "You said 'deploy in multiple regions' — how do you decide which SFU a user in São Paulo connects to?"
5. **Ask for self-critique** — "What's the weakest part of your design? What would you improve first?"

## Agent role
- `[explain]` — Walk through the recording pipeline pattern and multi-region considerations
- `[probe]` — Ask: "How do you record a 10-person meeting?" "What happens when a user in Brazil joins a meeting hosted in US-East?" "What's the biggest bottleneck?"
- `[scaffold]` — If they haven't considered recording: "Think about how YouTube records and stores videos. What's different for live meeting recordings?"

## Gotchas

1. **Recording blocks media path** — Recording should be async. Never let it block the live media flow.
2. **Multi-region stateful servers** — You can't just "deploy in 3 regions." Stateful servers need careful routing.
3. **Cross-region latency** — A meeting with participants in US and Europe needs a strategy.
4. **Forgetting consistency** — Meeting metadata needs to be consistent across regions.
5. **No trade-offs discussed** — Every design has weaknesses. Not identifying them shows lack of maturity.

## Success check

The learner has verbally demonstrated:
- Recording pipeline (async, not blocking media)
- Multi-region strategy (GeoDNS + regional SFU + routing)
- At least 4 trade-offs with analysis
- Self-identified bottlenecks and improvements
- Clear justification for each choice

If recording is inline: "What happens to the call if the recording service crashes?"
If multi-region is vague: "How do you decide which SFU a user in São Paulo connects to?"

The learner must explain *why* every design choice has a trade-off before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Why must recording be async, and what happens if it blocks the media path?

**Quiz topic 2 — Design:**
Why can't you just deploy stateful servers in multiple regions and load balance across them?

**Quiz topic 3 — Reflect:**
Why does "I'd just scale horizontally" show a lack of depth in a system design interview?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. Then point them to
**Step 7** and run `/systeminterview:next`.