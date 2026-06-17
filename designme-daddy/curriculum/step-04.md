---
step: 4
title: Data model
spine: -
kind: data
reference: -
---

# Step 4 — Data model

## Frame
The API says what data moves; now decide how it's **stored**. The key insight for ride-sharing is that one storage engine doesn't fit everything: trips and payments want relational integrity, the live location stream wants raw write throughput, and "who's near me" wants a geospatial index. Choosing the right engine per entity — and justifying it — is what separates a real data model from "put it all in one database."

## Teach the mechanisms
- **Entities and relationships** — identify the core entities (user/rider, driver, trip, location, maybe payment) and how they relate. *Why:* the relationships drive whether you need joins and transactions.
- **SQL vs NoSQL — the actual decision** — SQL gives transactions, joins, and strong consistency (reach for trips and payments); NoSQL key-value gives massive write throughput and horizontal scale with simple access (reach for the high-volume location stream). Point at the storage section of `docs/building-blocks-cheatsheet.md`. *Why:* matching the engine to the access pattern is the graded skill.
- **Where the live location lives** — current driver locations are written constantly and read by proximity. That's neither a normal SQL row nor a generic KV value; it belongs in (or in front of) a **geospatial index**, often kept in memory. The learner should separate *current* location (hot, in-memory/geo) from *historical* trip data (durable, relational).
- **Hot vs cold / expirable data** — raw pings are huge and mostly disposable; trips are small and permanent. Treat them differently.

A complete answer **lists the entities, assigns a storage engine to each with a reason tied to its access pattern, and treats live location differently from durable trip data.**

**GIVEN black box:** `docs/building-blocks-cheatsheet.md` is provided whole — the SQL-vs-NoSQL and replication notes. The learner uses it to justify choices; they aren't quizzed on the definitions.

## Spine  (the learner reasons this out themselves — no code, no file)
Have the learner produce: (1) the entity list with relationships, (2) a storage-engine choice per entity with a one-line justification rooted in the access pattern, and (3) an explicit decision about where current driver location lives versus historical trip data. Give the goal and shape; **wait**. Escalate via `/designme-daddy:hint`.

**Read first:** `docs/building-blocks-cheatsheet.md` (storage section)

## Agent role
- `[explain]` Explain the "engine per access pattern" idea with one example (trips→SQL, pings→KV/geo), then let the learner assign the rest.
- `[scaffold]` The building-blocks cheatsheet is GIVEN — point at the storage rows; don't reconstruct them.
- `[review]` Check each engine choice has a *reason* (not "because it's web-scale"), and that live location is separated from durable data.

## Gotchas
- **One database for everything.** Forcing the location ping flood into the same relational store as trips ignores the throughput mismatch you found in phase 2.
- **Engine by buzzword.** "NoSQL because it scales" with no access-pattern reason is the junior tell. The reason is the answer.
- **Putting live location in durable SQL rows.** Updating a row millions of times per second for ephemeral data is the wrong tool — and it ties back to the ping QPS from phase 2.
- **Ignoring consistency needs of money.** Payments/trips want transactional integrity; eventual consistency there is a real bug.

## Success check
No command to run. The phase is met when the learner has an entity list, a justified storage engine per entity, and an explicit, reasoned separation of live location from durable trip data.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
The tutor composes 2–3 open-ended questions from the learner's data model, scores 1–5, re-asks until each lands. Target the learner's own engine choices — never the cheatsheet's definitions.

**Quiz topic 1 — Diagnose:**
Take one of the learner's storage choices and ask what specifically breaks if the *other* engine were used there (e.g. trips in an eventually-consistent KV store; pings in a transactional SQL table).

**Quiz topic 2 — Design:**
Ask how their separation of live vs historical location data connects to the dominant write load they found in phase 2.

**Quiz topic 3 — Reflect:**
Ask for the one entity whose storage choice they're least sure about, and what they'd ask or test to decide.

## Next step  (do NOT ask the learner to choose)
There is one logical next phase: with entities and storage chosen, you assemble the services and draw how a request flows through them. Then point them to **Step 5** and run `/designme-daddy:next`.

Next: High-level architecture
