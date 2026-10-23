# replicant-lead

The **lead-mode** version of [replicant](../replicant/). Same system — database replication on top
of SQLite, in Ruby — but **you don't type the code. You lead an agent that does.**

Build-mode dojos keep the agent off the code so you learn by typing it. Lead mode keeps the agent
off the **decisions**: it writes the ADR and the whole implementation, and you decide every
guarantee, commit to numbers before the trial, review what it built, and answer for every line. The
skill being trained is the one that matters once agents write the code — deciding well, directing
precisely, and catching what the agent got wrong.

## How a step runs

Each step opens with an **incident** (a support ticket, an alert), reproduced live. Then:

1. **You direct a first-draft ADR** before being taught anything — a thin or wrong draft is expected.
2. **The tutor teaches against your draft**, and you direct the revision.
3. **You commit to expected results** — numbers, not adjectives. They are also the acceptance
   criteria the build is held to.
4. **The agent builds exactly what the ADR says**, then lists every choice it made that the ADR
   didn't (*unlisted choices*). You accept, reject, or promote each one into the ADR.
5. **You review its code against your ADR.** In the drill variant, it has planted a defect.
6. **The trial runs** — owned by the plugin, not the workspace — and lands next to your numbers.
7. **Free-text questions, scored 1–5**, starting from your biggest miss. No advance below 3.

The agent is a **scribe**: every decision row in the ADR carries your words in a `Learner said`
column, and when you leave something open it asks a plain question — no defaults, no "I'd
suggest". It counts those asks; the count measures how precisely you lead.

## Steps

| Step | Incident | You decide |
|---|---|---|
| 13 | "I saved my name, refreshed, the old one came back" | The read gate: read frontier, write reply, behind-node behavior, retries, watermark scope |

Lead mode enters the ramp mid-way: the transport, WAL and replication layers (replicant steps 1–12)
are a **GIVEN baseline** — a working 3-node cluster with a fault-injectable link — copied into
`workspace/` at setup.

## Run

```bash
./replicant-lead.sh ~/my-workshop     # create/enter that dir and run the dojo there
```

It runs on your own Claude Code login and quota — no API key. There is no local-model default:
building a replicated system needs a frontier model. You need `ruby` ≥ 3.2, `bundler`, and the
`sqlite3` CLI.

## Commands
- `/replicant-lead:start` — begin/resume the current step
- `/replicant-lead:trial` — run the step's trial and compare it with your expected results
- `/replicant-lead:next` — advance once the trial passed and you earned it
- `/replicant-lead:status` — progress, and every trial beside its expected results
- `/replicant-lead:hint` — a nudge toward a decision, never the decision
- `/replicant-lead:reveal` — instructor escape hatch: one reference set of decisions
- `/replicant-lead:setup` — one-time setup

## How it's wired
- **Hooks enforce order, not authorship.** `PreToolUse` blocks any write under `workspace/` until
  the step's ADR has all six sections and a number on every expected result, blocks the trial on
  the same condition, blocks edits to the GIVEN harness and the plugin, and keeps the build-mode
  offline jail (no web, no ad-hoc installs). `PostToolUse` records each `TRIAL_RESULT` in
  `.replicant-lead/results.csv` and hands the agent your expected results beside it.
- **Authorship is the tutor skill's job.** A hook can't tell whose idea a sentence was; the scribe
  rules, the provenance column, the scored questions and a human debrief are what catch an agent
  that did the thinking.
- **State** is per-project: `<project>/.replicant-lead/progress.json`.

## Layout
```
.claude-plugin/plugin.json    manifest
replicant-lead.sh             launcher (web off, prompt suggestions off)
skills/tutor/SKILL.md         the lead-mode tutor: two hats, scribe rules, eight beats
commands/                     start, trial, next, status, hint, reveal, setup
hooks/                        guard (the order), post-trial (results), session-start, title
bin/dojo.sh                   state helper (progress.json + steps.tsv)
bin/trial.sh                  runs env/trial/step-NN.rb (graded) or repro-NN.rb (the incident)
curriculum/step-13.md         incident / mechanisms / decision surface / ADR / expected results / review
curriculum/reference/         one defensible set of decisions per step, for reveal and the debrief
env/baseline/                 the GIVEN system copied into workspace/
env/trial/                    the plugin-owned trials and incident repros
env/docs/                     the offline docs bundle
```
