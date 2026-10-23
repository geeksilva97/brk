---
step: 13
title: The high-water mark read gate
spine: decisions/013-read-gate.md
kind: lead
reference: client_session.rb
---

# Step 13 — The high-water mark read gate

> **Lead mode.** The learner leads; the agent executes. The agent writes everything — the ADR and
> all of `workspace/` — but it **records decisions, it never makes them**. The learner's spine is
> the set of decisions in `decisions/013-read-gate.md`, and they answer for every line the agent
> ships.

## Frame  (deliver as an incident, not as a mechanism)
Support ticket, verbatim: *"I changed my display name, the page said 'saved', I refreshed and my old
name was back. Refreshed again and it was fixed. Happens maybe one time in five."*

Reproduce it before saying anything else: run `"${CLAUDE_PLUGIN_ROOT}/bin/trial.sh" 13 --repro`
(500 ms of replication delay to follower 7002, five saves, each followed by an immediate read from
it) and show the stale values. Do **not** name the
mechanism ("high-water mark", "read-your-writes"). Ask: *what is the system promising this user,
and where does it break that promise?*

The eight beats, the scribe rules, and the unlisted-choices report come from the tutor skill. This
file holds only what is specific to this step.

## Teach the mechanisms  (beat 3 — AFTER the first draft, never before)
- **Two frontiers per node.** The **log tail** is the highest index a node has *stored*; the
  **high-water mark** is the highest index it has *applied* and can safely serve.
- **The applied index is a logical clock.** A write returns the index it was assigned; a client
  that remembers "my write got index N" can ask any node to answer only if it has applied ≥ N.
- **The read gate.** A read carries a `min_index`; a node behind it must not serve.
- **Why this is enough for read-your-writes** — the client's own last write index is the only
  watermark it needs to never see its own data go stale (Turso/libSQL embedded replicas).

## Decision surface  (the learner owns every row; the agent may not fill any of them)
| Knob | What the learner must settle |
|------|------------------------------|
| Read frontier | Which per-node number a read is compared against |
| Write reply | What the client gets back on a successful write, and why |
| Behind-node behavior | Refuse? Block with a timeout (how long)? Forward to the leader? |
| Client retry policy | Which node next, how many attempts, backoff, when to give up |
| Watermark scope | Per session? Per key? Per connection? Where it lives and when it resets |
| Guarantee boundary | What this does **not** promise (other users' writes, cross-session reads) |

**Agent-owned (free):** wire encoding of the new fields, code layout, logging, test harness glue.

## The ADR  (`decisions/013-read-gate.md`, written by the agent, decided by the learner)
The guard blocks all code until these sections exist:

- `## Context` — the incident and the promise being broken, in the learner's framing.
- `## Decision` — a table with one row per decision-surface knob: `Knob | Decision | Learner said`.
- `## Alternatives` — at least two options the learner rejected, with their reason.
- `## Consequences` — what gets slower, what new failure appears, what it costs.
- `## Failure modes` — what happens when a follower is partitioned, not just lagging.
- `## Expected results` — see below. The trial is blocked until every item has a number.

## Expected results  (the learner commits to these BEFORE the trial)
Numbers, not adjectives. They are the acceptance criteria the build is held to, and the point of
the step: a guess written down before the run is the only proof the learner understood the system
before seeing the answer. The agent records them; it never proposes numbers or ranges.

- Stale reads out of 100 write-then-read cycles at 500 ms lag, **no gate**.
- Stale reads out of 100 cycles at 500 ms lag, **with the gate**.
- Read latency p50 / p99 with the gate at 500 ms lag.
- Refusals or retries per 100 reads with the gate.
- Stale reads out of 50 cycles with the gate when the follower *receives* each entry instantly but
  takes 200 ms to *apply* it.
- What a client sees when its follower is fully partitioned (lag = ∞), and after how many ms.

## Executor brief  (the agent, after the ADR passes the guard)
- `[build]` The read gate, the index in the write reply, and the client retry loop — as the ADR
  decides them. Likely unlisted choices to watch for: retry count, wait between retries, the error
  code a behind node returns, where the client stores its watermark.
- `[contract]` The trial drives `Client::Session` exactly as the header of `workspace/lib/client.rb`
  describes (`new`, `write`, `read(sql, prefer:)`, `retries`). Build to that contract; node-side
  changes go in `workspace/lib/node.rb`.
- The trial itself is the plugin's (`"${CLAUDE_PLUGIN_ROOT}/bin/trial.sh" 13`) — never write or
  modify a grader, and never change `bin/cluster`, `bin/link`, `lib/link.rb` or `lib/wire.rb`.

## Review checklist  (the learner reviews the agent's code; the tutor asks, never answers)
- Point at the line where a read is gated. Which number is it comparing against?
- Does the write reply actually carry the assigned index? Show where.
- When the node is behind, does the code do what the ADR says — or silently serve?
- Walk the unlisted choices report. Which of these is secretly a decision-surface row?

**Drill variant (instructor toggle):** the agent's first build gates on the stored tail instead of
the applied index, without saying so. The step does not advance until the learner finds it.

## Gotchas  (what the review and quiz should catch)
- Gating on the stored tail instead of the applied high-water mark.
- A write reply without the assigned index — the client has no watermark.
- Comparing indexes from different logs as if they were the same scale.
- A behind node that serves anyway "because the timeout expired" — the gate is gone.
- An ADR that fixes it by "always read from the leader" without pricing what that costs.
- Expecting ~20 stale reads because the ticket said "one in five" — the script reads milliseconds
  after the write, real users refresh seconds later. A good miss to dig into.

## Success check
The trial shows stale reads without the gate and **zero** with it — both at 500 ms replication lag
and under the 200 ms apply delay — and the partitioned read never returns stale data.
`results.csv` holds the measured row, and the post-trial hook has put it next to the expected
results. The ADR matches the code the
agent shipped, including every accepted unlisted choice, and every decision row has provenance.

## Consolidate  (dynamic quiz — AFTER the trial)
Generate the questions from this session, in this order of priority:
1. **The biggest miss.** Take the expected result they missed by the most. *Why* was reality
   different? A right answer names a mechanism, not luck.
2. **The road not taken.** Pick one of their rejected alternatives. Under what load or failure would
   it have been the better choice?
3. **The agent's choices.** Pick one unlisted choice they accepted. What breaks if it is wrong by
   10× in either direction?

Score 1–5; no advance below 3. Report the ask count. Then a single bare line:

Next: Monotonic and consistent-prefix reads.
