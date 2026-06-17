# designme-daddy

A **tutored system-design interview** as a Claude Code plugin. No code — just you and the whiteboard.
A Socratic tutor plays the interviewer for a ride-sharing service like Uber/Lyft, makes you reason out
every design decision yourself, scores each answer 1–5, and runs **offline by design** so you think
from first principles and a bundled set of cheatsheets instead of a web search.

It's modeled on the `c10k-dojo` shape (Socratic tutor + a fixed linear ramp + an enforced jail) but
adapted for a **no-code** topic: the "spine" you produce each step is *your design reasoning*, not a
file you type. The tutor never hands you the answer; it asks leading questions, reviews your reasoning,
pressure-tests it the way an interviewer would, and only advances when you've demonstrated
understanding.

## What it teaches

The standard 8-phase system-design interview, anchored on designing a ride-sharing service:

1. **Scope & requirements** — functional vs non-functional, narrow the problem, ask the right question
2. **Capacity estimation** — DAU → QPS, the location-ping firehose, storage & bandwidth
3. **API design** — the rider/driver/trip contract, push vs poll, idempotency
4. **Data model** — entities, SQL vs NoSQL per access pattern, where live location lives
5. **High-level architecture** — the core services, a request traced end to end, decoupling the write stream
6. **Deep dive: geospatial matching** — geohash / quadtree / S2, nearest-driver search, the moving-driver problem
7. **Scaling & bottlenecks** — sharding & the key choice, hot cells, caching, replication, surge
8. **Trade-offs & wrap-up** — CAP in practice, failure modes, MVP-vs-later, an honest summary

By the end you can drive a system-design interview end to end: quantify before you architect, go deep
once, and name your trade-offs out loud.

## Install / run

**One-shot launcher (recommended)** — runs the dojo in a project dir of your choosing, with web tools
and prompt suggestions disabled at the CLI:

```bash
./designme-daddy.sh                 # run in the current dir
./designme-daddy.sh /tmp/interview  # create/enter that dir and run there
```

Tip: symlink it onto your PATH so you can run it from anywhere:

```bash
ln -s "$PWD/designme-daddy.sh" ~/bin/designme-daddy
designme-daddy /tmp/interview
```

**Plain plugin load** (still works, but doesn't disable web/prompt-suggestions at the CLI level):

```bash
claude --plugin-dir ./designme-daddy
```

## Flow

1. **`/designme-daddy:setup`** — builds the offline cheatsheet bundle into `./docs/`. There are **no
   dependencies to install** — it's pure conversation. Run this once while online; afterward the guard
   hook jails the session offline. (On first launch the SessionStart hook runs setup for you.)
2. **`/designme-daddy:start`** — begins (or resumes) the interview at your current phase.
3. Work each phase with the tutor; advance with **`/designme-daddy:next`** when you've earned it.

## Commands

| Command | What it does |
|---|---|
| `/designme-daddy:setup` | One-time: build the offline cheatsheet bundle (no deps to install). |
| `/designme-daddy:start` | Begin or resume the interview at your current phase. |
| `/designme-daddy:next` | Advance to the next phase — only after the current phase's rubric + explain-it-back gate are met. |
| `/designme-daddy:status` | Show the 8-phase ramp, where you are, completed phases, backend mode. |
| `/designme-daddy:hint` | Smallest nudge for the current phase — cheatsheet pointer → leading question → partial scaffold. Never the full answer. |
| `/designme-daddy:reveal` | Instructor escape hatch — a model answer for the current phase, diffed against your attempt. |

## How it's wired

- **The jail = hooks.** `hooks/guard.sh` denies `WebFetch`/`WebSearch` and external Bash egress, so the
  interview stays offline and you reason from the cheatsheets + first principles. (The type-the-spine
  guard is a no-op here — there's no code file to protect; every step's spine is `-`.)
- **The tutor = a skill.** `skills/tutor/SKILL.md` drives the six-beat loop (frame → teach → produce →
  review → pressure-test → consolidate) and enforces the rules: fixed linear path, free-text answers
  scored 1–5, no advancement without understanding, no forward references, never quiz you on material
  it gave you.
- **State = per-project.** Progress lives in `<project>/.designme-daddy/progress.json` — a new folder
  starts fresh at phase 1. The SessionStart hook injects the current phase's curriculum and titles the
  session; the UserPromptSubmit hook re-titles only when the phase changes.
- **Cheatsheets = given black boxes.** `env/docs/*-cheatsheet.md` are copied into your `./docs/` bundle
  by `/setup`. They hand you the facts (latency numbers, capacity formulas, building blocks, geospatial
  primitives) so your thinking goes into the *decisions*, not memorization.

## Layout

```
designme-daddy/
├── designme-daddy.sh            # root launcher (web off, prompt-suggestions off)
├── .claude-plugin/plugin.json   # manifest (no "hooks" field — hooks/ auto-loads)
├── skills/tutor/SKILL.md        # the Socratic interviewer loop
├── hooks/
│   ├── hooks.json               # SessionStart + UserPromptSubmit + PreToolUse wiring
│   ├── session-start.sh         # resume at current phase, inject curriculum + title
│   ├── title.sh                 # re-title only when the phase changes
│   └── guard.sh                 # the offline jail (web + egress); spine guard is a no-op here
├── bin/dojo.sh                  # per-project state helper (get/advance/status), no jq
├── commands/                    # /setup /start /next /status /hint /reveal
├── env/docs/
│   ├── build-bundle.sh          # builds ./docs/ from the cheatsheets
│   ├── latency-numbers-cheatsheet.md
│   ├── capacity-estimation-cheatsheet.md
│   ├── building-blocks-cheatsheet.md
│   ├── geospatial-cheatsheet.md
│   └── interview-framework-cheatsheet.md
└── curriculum/
    ├── steps.tsv                # the 8-phase ramp (TAB-separated)
    ├── step-01.md … step-08.md  # one file per phase
    └── reference/               # (empty — no reference impls; /reveal composes from the rubric)
```
