---
step: 1
title: Scope & requirements
spine: -
kind: requirements
reference: -
---

# Step 1 — Scope & requirements

## Frame
Before a single box is drawn, a strong candidate pins down *what they are building and for whom*. "Design Uber" is deliberately vague — your first job is to turn it into a bounded problem by separating what the system must **do** (functional) from how **well** it must do it (non-functional), and by naming the scale you're targeting. Skip this and every later decision floats on assumptions you never made explicit.

## Teach the mechanisms
- **Functional vs non-functional requirements** — functional = the features (a rider requests a ride, a driver is matched, both see live location, the trip completes, payment happens). Non-functional = the qualities (low matching latency, high availability, consistency where money is involved, the scale in users/rides). *Why it matters:* the non-functional requirements are what make this a *systems* problem rather than a CRUD app.
- **Scoping the problem** — you cannot design everything. A senior move is to explicitly **narrow**: name the core flows you'll design and the ones you'll set aside (e.g. "I'll focus on rider↔driver matching and live tracking; I'll treat payments and ratings as out of scope for depth"). State your assumptions out loud and invite the interviewer to correct them.
- **The clarifying question** — interviews reward candidates who ask one or two sharp questions up front instead of assuming. ("Are we designing for a single city or global? Real-time matching or scheduled rides too?")

Point the learner at `docs/interview-framework-cheatsheet.md` (phase 1 row) for what this phase must deliver. A complete answer **separates functional from non-functional, names a concrete scale target, and states at least one assumption or clarifying question.**

<!-- GIVEN: the interview framework cheatsheet is provided as orientation; the learner does not derive the framework. -->
**GIVEN black box:** `docs/interview-framework-cheatsheet.md` is provided whole — it's the map of the 8 phases. The learner consults it but is never quizzed on it.

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner produce, in their own words: (1) a functional requirements list for the ride-sharing service, (2) a non-functional requirements list, (3) a stated scale target, and (4) one clarifying question they'd ask the interviewer. Give them the goal and the shape, then **wait** — do not list the requirements for them. If stuck, escalate via `/designme-daddy:hint`.

**Read first:** `docs/interview-framework-cheatsheet.md`

## Agent role
- `[explain]` Explain the functional/non-functional split and why scoping matters; give one example of each, then stop.
- `[scaffold]` The framework cheatsheet is GIVEN — point at it; don't make the learner reconstruct the phases.
- `[review]` Check their lists against the gotchas: did they conflate features with qualities? Did they name a scale? Did they over-scope? Name the specific gap and ask them to close it.

## Gotchas
- **Conflating functional and non-functional.** "It should be fast" is non-functional; "match a rider to a driver" is functional. Mixing them signals fuzzy thinking.
- **No scale target.** Without "X million daily riders," phase 2 has nothing to estimate from. Force a number, even a rough one.
- **Over-scoping.** Trying to design payments, ratings, surge, pooling, and matching all at once produces shallow everything. Narrowing is a strength, not a cop-out.
- **Skipping the clarifying question.** Diving straight into architecture without bounding the problem is the most common junior tell.

## Success check
There is no command to run. The phase is met when the learner has stated: a functional requirements list, a non-functional list (including at least latency + availability), an explicit scale target, and at least one clarifying question — and can defend why each non-functional requirement matters for *this* system.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions in the moment, scores each 1–5, and re-asks until each lands (score ≥ 3). Target the learner's OWN requirements list and scope decision — never the framework cheatsheet.

**Quiz topic 1 — Diagnose:**
Pick one non-functional requirement the learner named and ask what specifically breaks if it's *not* met (e.g. "what does a rider experience if matching latency is 30 seconds instead of 2?").

**Quiz topic 2 — Design:**
Ask why they scoped something *out* — what did setting that aside buy them, and what would they lose if the interviewer insisted on adding it back?

**Quiz topic 3 — Reflect:**
Ask for the single sharpest clarifying question for this problem and *why* its answer would change the design the most.

## Next step  (do NOT ask the learner to choose)
There is one logical next phase: now that you know *what* you're building and *at what scale*, you turn that scale into hard numbers. Then point them to **Step 2** and run `/designme-daddy:next`.

Next: Capacity estimation
