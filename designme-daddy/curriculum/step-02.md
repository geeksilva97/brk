---
step: 2
title: Capacity estimation
spine: -
kind: estimation
reference: -
---

# Step 2 — Capacity estimation

## Frame
A requirements list says *what* and *how well*; it doesn't tell you *where the system hurts*. Capacity estimation turns your scale target into numbers — QPS, storage, bandwidth — and those numbers decide every architectural choice that follows. For ride-sharing the surprise is almost always the same: the dominant load isn't ride requests, it's the flood of **location pings** from moving drivers.

## Teach the mechanisms
- **From DAU to QPS** — pick a daily active number, estimate actions per user, divide by ~86,400 seconds/day (round to 10^5). *Why:* average QPS is the baseline a single server count is sized against. Point at the seconds-per-day shortcut in `docs/capacity-estimation-cheatsheet.md`.
- **Peak vs average** — real traffic spikes (rush hour). Multiply average by a peak factor (2–10×) and say which you assume. *Why:* you provision for peak, not average.
- **The dominant write stream** — drivers ping GPS every few seconds whether or not they have a ride. (active drivers ÷ ping interval) is a write QPS that usually dwarfs ride-request QPS by orders of magnitude. Finding this is the whole point of the phase.
- **Storage & bandwidth** — objects × bytes/object (× replication, × growth); QPS × payload. Distinguish data that accumulates forever (trips) from data you can expire (raw pings).

A complete answer **shows the formula and the assumption, not just a number, and identifies location-ping ingestion as the dominant load.**

**GIVEN black box:** `docs/capacity-estimation-cheatsheet.md` and `docs/latency-numbers-cheatsheet.md` are provided whole — the formulas, powers of 2, and the seconds-per-day shortcut. The learner applies them; they don't derive them.

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner estimate, with stated assumptions and visible formulas: (1) average and peak ride-request QPS, (2) location-update write QPS, (3) rough storage for trips and for raw location data, and (4) a one-sentence conclusion about where the load concentrates. Give them the shape; make them pick the assumptions and do the arithmetic. **Wait.** Escalate via `/designme-daddy:hint` (point at the cheatsheet shortcut) if stuck.

**Read first:** `docs/capacity-estimation-cheatsheet.md`, `docs/latency-numbers-cheatsheet.md`

## Agent role
- `[explain]` Explain the DAU→QPS pipeline and peak factor with one tiny worked example, then stop and let them run their own numbers.
- `[scaffold]` The cheatsheets are GIVEN — quote the seconds-per-day shortcut for them; don't make them re-derive it.
- `[review]` Check the arithmetic's *order of magnitude* (not exact digits), check assumptions are stated, and check they spotted the location-ping dominance.

## Gotchas
- **A number with no formula.** "About 50,000 QPS" with no shown work is unverifiable and ungradable. Always formula-then-number.
- **Forgetting the ping stream.** Estimating only ride requests and missing the continuous location writes is the classic miss — and it's exactly the load that shapes the architecture.
- **Average-only provisioning.** Ignoring the peak factor under-provisions for rush hour.
- **Wrong order of magnitude.** Exact digits don't matter; being off by 1000× (GB vs TB, thousands vs millions of QPS) does.

## Success check
No command to run. The phase is met when the learner has produced QPS (avg + peak), storage, and the location-write estimate — each with a visible formula and stated assumption — and has concluded, in their own words, that location-ping ingestion is the dominant load and why.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions from the learner's actual numbers, scores 1–5, re-asks until each lands. Target the learner's own estimates and assumptions — never the cheatsheet's formulas themselves.

**Quiz topic 1 — Diagnose:**
Take an assumption the learner made (e.g. ping interval, peak factor) and ask how the headline number moves if that assumption is wrong by 2–3×, and what that would change downstream.

**Quiz topic 2 — Design:**
Ask why the location-ping QPS dwarfs the ride-request QPS, and what that difference implies about which part of the system needs the most engineering.

**Quiz topic 3 — Reflect:**
Ask for the single number from this phase that most constrains the rest of the design, and why.

## Next step  (do NOT ask the learner to choose)
There is one logical next phase: with the load quantified, you define the contract the clients and the system speak — the API. Then point them to **Step 3** and run `/designme-daddy:next`.

Next: API design
