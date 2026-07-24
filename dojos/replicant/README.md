# replicant

A Claude Code **plugin** that tutors you into building **database replication from scratch on top of
SQLite** — a networked node, a hand-written write-ahead log, leader→follower replication, and finally
quorum-based leader election (the safety core of Raft) — under a deliberate constraint (no web
access; you reason from a mounted Ruby + SQLite docs bundle and first principles).

SQLite gives you a real storage engine and SQL for free, so **100% of your effort goes into the
distribution layer**. You build the logical-replication path (a log of SQL commands applied to each
node's own SQLite, the way `rqlite` does), and every distributed-systems pattern arrives as a
**measured pain you feel and then fix** — a stale read, a lost write, a split brain — using a
fault-injectable link you build in the first layer and turn knobs on for the rest of the course.

Claude Code acts as a **Socratic tutor**: it frames each problem, teaches the mechanism, makes **you
type the load-bearing code**, reviews it by pointing at lines, and quizzes you with free-text
questions (scored 1–5) before it lets you advance. It writes only glue and given black boxes — never
your spine.

## Install (local dev)

```bash
# One-shot launcher (disables web + prompt suggestions at the CLI level):
./replicant.sh ~/my-workshop     # create/enter that dir and run the dojo there
# …or the bare claude path:
claude --plugin-dir ./replicant
# then, in the project where you'll build:
/replicant:setup     # vendor the sqlite3 gem + build the offline docs bundle
/replicant:start     # begin (or resume) at your current step
```

You need `ruby` (≥ 3.0), `bundler`, and the `sqlite3` CLI on your PATH. `/replicant:setup` vendors the
one gem dependency (`sqlite3`) while the network is still available, then the jail closes.

## The ramp (20 steps, six layers)

| Layer | Steps | You build |
|------|------|-----------|
| **Transport** | 1–5 | A node on a socket: length-prefix framing, a request/response envelope, a fault-injectable peer link, an idempotent receiver. |
| **Write-ahead log** | 6–9 | An append-only log of commands, fsync-before-apply, replay-on-startup recovery, a single-writer queue. |
| **Replication** | 10–12 | Leader→follower log shipping, the follower applying to its own SQLite, and the determinism fix (capture-and-rewrite `RANDOM()`/`now`). |
| **Consistency** | 13–14 | The high-water mark read gate (read-your-writes), then monotonic and consistent-prefix reads. |
| **Crash & recovery** | 15–17 | Follower catch-up, heartbeat failure detection, and the generation clock that kills split-brain-in-time. |
| **Election & quorum** | 18–20 | Naive election (feel the split brain), majority-quorum election, and quorum commit — a single-leader replicated log ≈ Raft. |

Sharding is a deliberate *next phase*, not part of v1.

## Commands
- `/replicant:start` — begin/resume the current step's tutored loop
- `/replicant:next` — advance after the success check + explain-it-back gate
- `/replicant:status` — progress + the full layered ramp with a marker on where you are
- `/replicant:hint` — a scoped nudge that never reveals the full spine
- `/replicant:reveal` — instructor escape hatch: show the reference impl (if any)
- `/replicant:setup` — one-time environment setup

## How it's wired
- **Hooks are the jail.** `PreToolUse` denies `WebFetch`/`WebSearch` and external Bash egress (only
  `localhost` is reachable — that's where your nodes listen), blocks ad-hoc dependency installs, and
  blocks the agent from writing the current step's *spine* file (you type that). `SessionStart`
  resumes you at your step and injects its curriculum; `UserPromptSubmit` keeps the session title in
  sync at each `/next` boundary.
- **State** is per-project: `<project>/.replicant/progress.json` — keyed to the folder you're in, so a
  new folder starts fresh at Step 1 and progress survives across sessions within that project.
- **Backend model:** the default is a local model via **Ollama** (or llama.cpp) — a true air-gap.
  Pull one (`ollama pull qwen2.5-coder:32b`) and launch with `--model qwen2.5-coder:32b` (the
  `replicant.sh` wrapper forwards it; Ollama serves on `:11434`); the Anthropic API is an optional
  easy-mode. Either way Claude Code is the harness and the flow is identical.

## Layout
```
.claude-plugin/plugin.json    manifest
replicant.sh                  launch script (one-shot: disables web + prompt suggestions)
skills/tutor/SKILL.md         the six-beat Socratic loop
commands/                     the six slash commands
hooks/                        session-start, title, guard (the jail)
bin/dojo.sh                   state helper (progress.json + steps.tsv)
curriculum/step-01..20.md     the steps (frame / teach / spine / gotchas / check / quiz)
curriculum/steps.tsv          step → title/spine/kind table
env/docs/build-bundle.sh      builds the offline docs bundle
env/docs/*-cheatsheet.md      the GIVEN black boxes (sockets, pack/unpack, sqlite3, wire protocol)
```

Grounded in Martin Kleppmann's *Designing Data-Intensive Applications* (ch. 5–6) and Unmesh Joshi's
*Patterns of Distributed Systems*. The real-world system it mirrors is `rqlite` (SQLite + Raft).
