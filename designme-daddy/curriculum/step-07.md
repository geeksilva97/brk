---
step: 7
title: Scaling & bottlenecks
spine: -
kind: scaling
reference: -
---

# Step 7 — Scaling & bottlenecks

## Frame
A design that works at your estimated scale isn't done — the interviewer will push it to 10–100×. This phase is where you name the *specific* points that break first and the *specific* technique that fixes each. "Just scale it" is not an answer; "the downtown geo-cell becomes a hot shard, so I'd sub-partition hot cells and cache the hot driver set" is.

## Teach the mechanisms
- **Find the first bottleneck** — usually the location-ingestion path and the live index (from phases 2 and 6). Name it before you fix it. Point at `docs/building-blocks-cheatsheet.md` (scaling techniques) and `docs/latency-numbers-cheatsheet.md`.
- **Sharding and the key choice** — split the index/data across nodes by a partition key (geo-cell, region). *Why:* no single node can hold the whole live index. The key choice is everything — a bad key creates hot shards.
- **Hot shards / hot cells** — a dense downtown cell gets far more traffic than the ocean. Mitigate by sub-partitioning hot cells, replicating them, or adjusting cell granularity. This is the phase's signature problem.
- **Caching** — RAM reads are ~100× faster than SSD (latency sheet). Cache the hot driver sets and hot lookups; name the invalidation cost.
- **Replication for reads + failover** — read replicas absorb read load and survive node loss, at the cost of replication lag.
- **Surge as a load+business lever** — demand-aware pricing per cell both monetizes and *sheds* load in hot areas. Worth naming as a real mechanism, not a gimmick.

A complete answer **names a specific first bottleneck, applies a specific technique (with its key/choice), and confronts hot shards explicitly.**

**GIVEN black box:** `docs/building-blocks-cheatsheet.md` (scaling techniques: replication, sharding, consistent hashing) is provided whole. The learner *applies* these; they aren't quizzed on the definitions.

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner: (1) name the first component that breaks under 10–100× and why, (2) propose a sharding strategy with an explicit partition key and defend it, (3) address hot cells/shards specifically, and (4) name where caching and/or replication help and what each costs. Give the goal and shape; **wait**. Escalate via `/designme-daddy:hint`.

**Read first:** `docs/building-blocks-cheatsheet.md` (scaling techniques), `docs/latency-numbers-cheatsheet.md`

## Agent role
- `[explain]` Explain how to hunt a bottleneck (follow the biggest load) and what a partition key does; let the learner pick the key and defend it.
- `[scaffold]` The scaling-techniques notes are GIVEN — point at sharding/replication/consistent-hashing; the learner applies them.
- `[review]` Check the bottleneck is *specific*, the shard key is justified, and hot shards are addressed rather than hand-waved.

## Gotchas
- **"Just add servers."** Horizontal scaling only helps stateless tiers; the stateful index/DB needs sharding and a key choice. Vague scaling is the main failure here.
- **A bad shard key.** Sharding location by something that clusters traffic (or by a key that splits related data) creates hot shards or cross-shard queries.
- **Ignoring hot cells.** Uniform sharding assumes uniform load; cities aren't uniform. Not addressing the dense-cell problem is the signature miss.
- **Caching without invalidation.** A cache of driver positions that never expires serves stale locations — name the freshness/invalidation cost.

## Success check
No command to run. The phase is met when the learner has named a specific first bottleneck, proposed and justified a sharding key, explicitly handled hot shards/cells, and placed caching/replication with their costs.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions from the learner's scaling plan, scores 1–5, re-asks until each lands. Target the learner's own bottleneck and shard-key choices — never the cheatsheet's technique definitions.

**Quiz topic 1 — Diagnose:**
Take the learner's shard key and ask for a traffic pattern that would still create a hot shard despite it, and what they'd do then.

**Quiz topic 2 — Design:**
Ask why caching the hot driver set is worth the invalidation complexity — push them to quote the latency gap from the numbers sheet.

**Quiz topic 3 — Reflect:**
Ask which scaling decision they made carries the biggest hidden cost, and how they'd know in production if it was the wrong call.

## Next step  (do NOT ask the learner to choose)
There is one logical next phase: you step back and name the trade-offs, failure modes, and what you'd build first — the senior wrap-up. Then point them to **Step 8** and run `/designme-daddy:next`.

Next: Trade-offs & wrap-up
