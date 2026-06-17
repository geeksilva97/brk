---
step: 5
title: High-level architecture
spine: -
kind: architecture
reference: -
---

# Step 5 — High-level architecture

## Frame
You have requirements, numbers, an API, and a data model. Now draw the **boxes and arrows**: the core services and how a request flows through them end to end. The goal isn't a pretty diagram — it's to show that the pieces you've chosen actually connect into a working system, with the location-ping flood and the rider↔driver match each handled by something built for it.

## Teach the mechanisms
- **Decompose into services by responsibility** — at minimum a gateway/LB at the edge, a location/ingestion service for the ping stream, a matching service that finds nearby drivers, and a trip service that owns the ride lifecycle. *Why:* separating the high-write ingestion path from the matching path lets each scale independently. Point at the edge/compute/messaging sections of `docs/building-blocks-cheatsheet.md`.
- **Trace a request end to end** — "rider requests a ride → gateway → matching service queries the live driver index → returns a candidate → trip service creates the trip → both clients get updates." Being able to narrate one full flow proves the boxes connect.
- **Absorbing the write stream** — the location-ping firehose usually goes through a **queue** into the ingestion service so a burst doesn't topple the matching path. Naming this decoupling is a senior signal.
- **Stateless where possible** — app services that hold no state scale by adding instances behind the LB; the stateful parts (the live index, the databases) are where the hard scaling lives.

A complete answer **names the core services, traces at least one request end to end, and shows the high-write location path decoupled from the matching/trip path.**

**GIVEN black box:** `docs/building-blocks-cheatsheet.md` is provided whole — the component menu. The learner assembles from it; they aren't quizzed on what an LB or a queue is.

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner describe the architecture in their own words: the core services and their responsibilities, the data stores from phase 4 attached to the right services, and a full trace of one request (a ride request) flowing through the system. Then have them show where the location-ping stream enters and how it's kept from overwhelming matching. Give the goal and shape; **wait**. Escalate via `/designme-daddy:hint`.

**Read first:** `docs/building-blocks-cheatsheet.md` (edge, compute, messaging)

## Agent role
- `[explain]` Explain decomposition-by-responsibility and what "trace a request" means; offer the *idea* of separating ingestion from matching, not the finished diagram.
- `[scaffold]` The component menu is GIVEN — point at it; the learner picks and wires the boxes.
- `[review]` Check the services have clear responsibilities, the request trace is complete (no magic hops), and the write stream is decoupled.

## Gotchas
- **One monolith box.** "An app server and a database" doesn't show you understand the independent scaling needs you uncovered in phase 2.
- **Boxes with no arrows.** Listing services without tracing a request hides whether they actually connect.
- **Synchronous ping ingestion.** Writing every GPS ping straight through to the matching path couples a firehose to a latency-sensitive operation; a queue decouples them.
- **Stateful everything.** Not distinguishing stateless app services from the stateful index/DBs misses where the real scaling problem is (which is exactly the next phase's deep dive).

## Success check
No command to run. The phase is met when the learner has named the core services with responsibilities, traced one request end to end through them, attached the phase-4 stores correctly, and shown the location stream decoupled from the matching path.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions from the learner's architecture, scores 1–5, re-asks until each lands. Target the learner's own decomposition and request trace — never the cheatsheet's component definitions.

**Quiz topic 1 — Diagnose:**
Ask what happens to the rider's experience if the location-ingestion path and the matching path are *not* decoupled and a traffic burst hits.

**Quiz topic 2 — Design:**
Ask why they split responsibilities the way they did — what does giving matching its own service let them do that a monolith couldn't?

**Quiz topic 3 — Reflect:**
Ask which single service in their diagram is the most load-bearing, and what they'd look at first if the whole system felt slow.

## Next step  (do NOT ask the learner to choose)
There is one logical next phase: you go deep on the hardest subsystem — finding the nearest drivers fast while they're all moving. Then point them to **Step 6** and run `/designme-daddy:next`.

Next: Deep dive: geospatial matching
