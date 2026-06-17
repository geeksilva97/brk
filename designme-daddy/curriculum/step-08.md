---
step: 8
title: Trade-offs & wrap-up
spine: -
kind: tradeoffs
reference: -
---

# Step 8 — Trade-offs & wrap-up

## Frame
A complete design names its own weaknesses. This final phase is the senior signal: you step back from the diagram and articulate the trade-offs you made, the failure modes you'd guard against, what you'd build first versus defer, and an honest one-paragraph summary. Pretending the design has no soft spots is the surest way to look junior; naming them is what looks senior.

## Teach the mechanisms
- **CAP in practice** — under a network partition you pick consistency or availability. Map it to *this* system: payments/trip records want strong consistency; live driver locations and ETAs can tolerate eventual consistency and staleness. Point at the CAP/consistency notes in `docs/building-blocks-cheatsheet.md`.
- **Failure modes** — what happens when a component dies? The live index node, the matching service, the queue backing up. Name the blast radius and the mitigation (replication, retries with idempotency, graceful degradation).
- **MVP vs later** — what's the smallest version that delivers the core value (request → match → track → complete), and what's deferred (surge, pooling, ratings)? Sequencing shows product judgment.
- **Honest summary** — restate the design in a few sentences, lead with the load that shaped it (location pings) and the deep dive (geospatial matching), and own the biggest remaining risk.

A complete answer **names a concrete consistency trade-off for this system, at least one failure mode with a mitigation, an MVP-vs-later split, and a crisp summary that owns a weakness.**

**GIVEN black box:** `docs/building-blocks-cheatsheet.md` (CAP, idempotency) and `docs/interview-framework-cheatsheet.md` (wrap-up row) are provided whole. The learner applies them; they aren't quizzed on the definitions.

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner deliver: (1) one explicit consistency/availability trade-off mapped to a specific part of the system, (2) at least one failure mode and its mitigation, (3) an MVP-vs-later split, and (4) a short spoken summary of the whole design that owns its biggest weakness. Give the goal and shape; **wait**. Escalate via `/designme-daddy:hint`.

**Read first:** `docs/building-blocks-cheatsheet.md` (CAP / cross-cutting), `docs/interview-framework-cheatsheet.md`

## Agent role
- `[explain]` Explain how to map CAP to concrete parts of a system and what makes a good wrap-up; let the learner make the calls.
- `[scaffold]` The CAP/idempotency notes and the framework wrap-up row are GIVEN — point at them; the learner applies.
- `[review]` Check the trade-off is *specific to this system* (not a textbook recital), a real failure mode is mitigated, and the summary honestly owns a weakness.

## Gotchas
- **CAP as a recital.** Quoting "consistency, availability, partition tolerance" without mapping it to *this* system's payments-vs-locations split is empty.
- **A design with no weaknesses.** Claiming everything is solved reads as not understanding the trade-offs you made.
- **No MVP thinking.** Treating every feature as equally essential shows no prioritization judgment.
- **Forgetting failure.** A happy-path-only design ignores that nodes die and queues back up.

## Success check
No command to run. The phase is met when the learner has stated a system-specific consistency trade-off, a failure mode with a mitigation, an MVP-vs-later split, and a summary that honestly names the biggest remaining risk.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions from the learner's wrap-up, scores 1–5, re-asks until each lands. Target the learner's own trade-off calls and summary — never the cheatsheet's CAP definition.

**Quiz topic 1 — Diagnose:**
Take the learner's consistency choice for one component and ask what a user actually experiences when the partition they bet against happens.

**Quiz topic 2 — Design:**
Ask why their MVP cut is the right first slice — what core value does it deliver, and what's safe to defer and why?

**Quiz topic 3 — Reflect:**
Ask for the single biggest risk in their whole design and how they'd de-risk it if they had one more week.

## Next step  (do NOT ask the learner to choose)
That's the full interview — you scoped a ride-sharing service, sized it, designed its API and data model, drew its architecture, went deep on geospatial matching, scaled it, and owned its trade-offs end to end. Congratulations: you've completed designme-daddy. Run `/designme-daddy:status` to see your completed ramp, and try running the whole interview again on a fresh problem to make the framework second nature.
