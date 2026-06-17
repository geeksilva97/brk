# GIVEN cheatsheet — The system-design interview framework

> **This is GIVEN scaffolding.** It orients you on the 8 phases and what each delivers. The framework
> is the *map*; the territory — the actual decisions for ride-sharing — is what you produce in each phase.

A strong system-design interview is not a brain-dump. It's a **structured walk** from "what are we even
building?" to "here's why this scales and where it breaks." Drive it in this order; don't jump ahead.

| Phase | You deliver | The trap to avoid |
|---|---|---|
| 1. **Scope & requirements** | Functional (what it does) + non-functional (latency, availability, consistency, scale) requirements; the one or two things you'd clarify with the interviewer | Jumping to architecture before you know what you're building |
| 2. **Capacity estimation** | DAU, the dominant load (location pings!), QPS (avg + peak), storage, bandwidth — with formulas and assumptions stated | A bare number with no formula; wrong order of magnitude |
| 3. **API design** | The core endpoints/contracts between client and system (request ride, update location, accept, track) | Designing internals before the external contract |
| 4. **Data model** | Entities, relationships, and the storage engine per entity (SQL vs NoSQL vs geo) with justification | "Just use Postgres" / "just use Mongo" with no reasoning |
| 5. **High-level architecture** | The boxes and arrows: the core services and how a request flows through them | A single monolith box, or boxes with no data flow |
| 6. **Deep dive** | One hard subsystem in depth — for ride-sharing, geospatial matching: index choice, nearest-driver search, the moving-driver write problem | Staying shallow everywhere instead of going deep on the hard part |
| 7. **Scaling & bottlenecks** | Where it breaks at 10–100×, and the fix: caching, sharding (and the key), replication, queues, hot-cell/hot-shard handling, surge | Adding "scale it" hand-waving with no specific bottleneck named |
| 8. **Trade-offs & wrap-up** | The consistency/availability calls (CAP), failure modes, what you'd build first (MVP) vs later, and an honest summary | No trade-offs named; pretending the design has no weaknesses |

## The meta-skill interviewers actually score
- **Drive the conversation** — don't wait to be asked; narrate your structure.
- **Quantify** — turn vibes into numbers (phase 2 feeds every later decision).
- **Name trade-offs** — every choice has a cost; saying the cost out loud is the signal of seniority.
- **Go deep once** — breadth everywhere reads as shallow; one strong deep dive reads as senior.
- **Stay scoped** — clarify, then commit; don't redesign the world.
