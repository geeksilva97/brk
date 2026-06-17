---
step: 6
title: "Deep dive: geospatial matching"
spine: -
kind: deepdive
reference: -
---

# Step 6 — Deep dive: geospatial matching

## Frame
Breadth everywhere reads as shallow; one strong deep dive reads as senior. The hardest subsystem in ride-sharing is finding the nearest available drivers in milliseconds *while every driver is moving and re-pinging their location constantly*. A naïve `(lat, lng)` scan can't do it. This phase is where you pick a spatial index, defend it, and confront the moving-driver write problem head on.

## Teach the mechanisms
- **Why a plain coordinate scan fails** — latitude and longitude are two independent dimensions; a single B-tree indexes one, so "within 2 km" becomes a slow scan. You need an index that turns 2D proximity into a 1D-searchable key. Point at `docs/geospatial-cheatsheet.md`.
- **The three indexes** — geohash (prefix = proximity, dead simple, easy to shard), quadtree (adapts to density, great for cities vs countryside), S2 (sphere-correct cell IDs, global scale). *Why:* each is a different trade-off; picking and justifying one is the skill.
- **Nearest-driver search** — compute the rider's cell, look up the live driver set in that cell *and its neighbors* (boundary points fall in adjacent cells), then rank by actual distance/ETA. The neighbor step is the easy-to-miss part.
- **The moving-driver write problem** — every ping may move a driver to a new cell, so the index updates constantly. This is the write-amplification that connects straight back to the ping QPS from phase 2.

A complete answer **picks one index with a justification, describes the nearest-driver lookup including neighbor cells, and confronts the constant-update problem for moving drivers.**

**GIVEN black box:** `docs/geospatial-cheatsheet.md` is provided whole — how geohash/quadtree/S2 encode location and their trade-offs. The learner *chooses and justifies*; they are never quizzed on how a geohash is encoded.

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner: (1) choose a spatial index and justify it against the alternatives, (2) walk through how a rider's "find nearby drivers" query executes (including the neighbor-cell detail), and (3) explain how the index stays current as drivers move, tying it to the ping load. Give the goal and shape; **wait**. Escalate via `/designme-daddy:hint` (point at the cheatsheet's "the hard part" section).

**Read first:** `docs/geospatial-cheatsheet.md`, `docs/latency-numbers-cheatsheet.md`

## Agent role
- `[explain]` Explain why the naïve scan fails and what "1D-searchable proximity" means; let the learner pick the index.
- `[scaffold]` The geospatial cheatsheet is GIVEN — the learner consults it for how each index works; don't make them derive the encodings.
- `[review]` Check the index choice is *justified* (not just named), the neighbor-cell step is present, and the moving-driver update is addressed.

## Gotchas
- **Naming an index without justifying it.** "Use geohash" with no comparison to the alternatives is half an answer.
- **Forgetting neighbor cells.** A rider near a cell boundary will miss the closest driver if you only search their own cell.
- **Ignoring that drivers move.** Treating the index as static — built once and queried — skips the actual hard part and contradicts the phase-2 ping load.
- **Confusing "in the cell" with "nearest."** Cell membership is a coarse filter; you still rank candidates by real distance/ETA.

## Success check
No command to run. The phase is met when the learner has chosen and justified a spatial index, described the nearby-driver query including neighbor cells and a final distance/ETA rank, and explained how the index is kept current under the moving-driver ping load.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions from the learner's deep dive, scores 1–5, re-asks until each lands. Target the learner's own index choice and search description — never the cheatsheet's encoding details.

**Quiz topic 1 — Diagnose:**
Ask what query result is wrong if neighbor cells are skipped, with a concrete rider-near-the-boundary example.

**Quiz topic 2 — Design:**
Ask why they chose their index over the two alternatives, and name one scenario where the alternative would have been better.

**Quiz topic 3 — Reflect:**
Ask how the moving-driver update cost connects to the dominant load they estimated back in phase 2 — what's the through-line?

## Next step  (do NOT ask the learner to choose)
There is one logical next phase: you take the whole design to 10–100× and find where it breaks. Then point them to **Step 7** and run `/designme-daddy:next`.

Next: Scaling & bottlenecks
