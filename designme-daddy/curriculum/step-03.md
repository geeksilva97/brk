---
step: 3
title: API design
spine: -
kind: api
reference: -
---

# Step 3 — API design

## Frame
You know what you're building and how much load it carries. Now define the **contract**: the small set of operations clients invoke and what each takes and returns. Designing the external API before the internals forces you to think in terms of *what the system promises* rather than how it's wired — and it surfaces real questions (how does a client track a ride? push or poll?) that internal diagrams hide.

## Teach the mechanisms
- **Endpoints as a contract** — name the core operations as request/response shapes: request a ride, update driver location, accept/decline a match, fetch trip status. *Why:* the API is the seam between client and system; getting it right scopes everything behind it.
- **Who calls what** — riders and drivers are different clients with different operations. Separating them clarifies the design.
- **Real-time delivery: push vs poll** — a rider watching a driver approach needs live updates. Polling (client asks repeatedly) is simple but wasteful; a push channel (long-lived connection / server push) is efficient but stateful. The learner should name the choice and the trade-off, pointing at the queue/connection notes in `docs/building-blocks-cheatsheet.md`.
- **Idempotency** — "request ride" sent twice (retry on a flaky network) must not create two rides. An idempotency key makes a retried call safe. *Why:* mobile clients retry constantly.

A complete answer **names the core operations with their inputs/outputs, separates rider and driver flows, and makes a deliberate push-vs-poll call for live tracking.**

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner sketch the core API in their own words: the operation names, what each accepts and returns, and which client calls it. Then have them decide how live location reaches the rider (push or poll) and justify it, and name where idempotency matters. Give them the goal and shape; **wait**. Escalate via `/designme-daddy:hint` if stuck.

**Read first:** `docs/building-blocks-cheatsheet.md` (messaging / edge sections)

## Agent role
- `[explain]` Explain what makes a good API contract and the push-vs-poll trade-off; offer the *categories* of operations, not the finished list.
- `[scaffold]` The building-blocks cheatsheet is GIVEN — point at the queue/connection notes for the push option.
- `[review]` Check that operations have clear inputs/outputs, rider/driver flows are separated, and the live-tracking choice is justified rather than assumed.

## Gotchas
- **Designing internals first.** Jumping to databases and services before the contract means the API ends up shaped by accidents of the implementation.
- **Polling by default.** Choosing polling without acknowledging the cost (latency vs request volume) of the alternative is a missed trade-off.
- **No idempotency on ride requests/payments.** Mobile retries will create duplicate rides or double charges without it.
- **One undifferentiated client.** Treating rider and driver as the same caller hides that they have different operations and access patterns.

## Success check
No command to run. The phase is met when the learner has stated the core operations (with inputs/outputs), separated rider and driver flows, made and justified a push-vs-poll decision for live tracking, and identified where idempotency is required.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions from the API the learner designed, scores 1–5, re-asks until each lands. Target the learner's own API choices — never the cheatsheet's component definitions.

**Quiz topic 1 — Diagnose:**
Ask what goes wrong if the live-tracking channel they chose is used the other way (e.g. polling at the ping frequency, or holding a push connection for millions of idle clients).

**Quiz topic 2 — Design:**
Ask why they split (or didn't split) rider and driver operations, and how that split helps a later part of the design.

**Quiz topic 3 — Reflect:**
Ask which single operation in their API carries the most risk if it's slow or wrong, and why.

## Next step  (do NOT ask the learner to choose)
There is one logical next phase: with the contract defined, you decide how the data behind it is modeled and stored. Then point them to **Step 4** and run `/designme-daddy:next`.

Next: Data model
