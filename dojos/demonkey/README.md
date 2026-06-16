# demonkey

A Claude Code **plugin** that tutors you into building Ruby web servers through the **process family
only** — from a raw TCP socket all the way to a **Unicorn-like preforking server** with heartbeats,
graceful shutdown, and zero-downtime `USR2` restart — under a deliberate constraint (no web access;
you reason from a mounted Ruby + C docs bundle and first principles).

Claude Code acts as a **Socratic tutor**: it frames each problem, teaches the mechanisms and points
you at the docs, makes **you type the load-bearing code**, then — once it's built and running — quizzes
you with free-text consolidation questions, scoring your explanation 1–5 and giving feedback. It handles
boilerplate and review; you build first, and the quizzes come after the thing works. Verification is **local and lightweight** — `nc`
clients, `ps`/`lsof` for zombies and fd leaks, `kill -SIGNAL` to drive the signal protocol, and a
`USR2` restart with a live client to prove zero downtime. The emphasis is *building and signals*, not
load testing.

This is a focused **pilot** of `c10k-dojo`. It deliberately covers only the process family. **Out of
scope:** threads, the GVL, fibers, the fiber scheduler, Falcon/async, Ractors, and the C10K
benchmark — those are a separate course.

## Install (local dev)

```bash
claude --plugin-dir ./demonkey
# then, in the project where you'll build:
/demonkey:setup     # vendor the pinned gems + build the offline docs bundle
/demonkey:start     # begin (or resume) at your current step
```

## The course (7 steps)

1. **Raw TCP echo server** — a single blocking accept loop. Feel it hang on the 2nd client.
2. **Rack app over a raw socket** — `protocol-http1` as a black box; the env adapter is the seam.
3. **Why one server is not enough** — no code; watch one slow request stall everything (local demo).
4. **Fork-per-connection** — fork, fd inheritance, the parent/child closes, reaping zombies.
5. **Preforking N workers** — open the socket once, fork a fixed pool, kernel load-balances `accept`.
6. **Master: signals & reaping** — a supervisor that doesn't accept; SIGCHLD+WNOHANG reaping, the
   self-pipe trick, respawn, `TTIN`/`TTOU`, clean `TERM`/`QUIT`.
7. **Production-grade preforking** — heartbeats + timeout-kill, graceful shutdown, and `USR2`
   zero-downtime restart with an inherited socket fd. The unicorn thing.

## Commands
- `/demonkey:start` — begin/resume the current step's tutored loop
- `/demonkey:next` — advance after the success check + explain-it-back gate
- `/demonkey:status` — progress + the arc you've climbed
- `/demonkey:hint` — a scoped nudge that never reveals the full spine
- `/demonkey:reveal` — instructor escape hatch: show the reference impl
- `/demonkey:setup` — one-time environment setup (gems + docs bundle)

## How it's wired
- **Hooks are the jail.** `PreToolUse` denies `WebFetch`/`WebSearch` and external Bash egress, and
  blocks the agent from writing the current step's *spine* file (you type that). `SessionStart`
  resumes you at your step, injects its curriculum, and sets the title. `UserPromptSubmit` keeps the
  title in sync at `/next` boundaries (no per-prompt churn).
- **State** is per-project: `<project>/.demonkey/progress.json` (keyed to the folder you're in,
  so a new folder starts fresh at Step 1; survives sessions within that project).
- **No benchmark.** Verification is local (`nc` / `ps` / `lsof` / `kill -SIGNAL`); every step's
  curriculum file has a concrete success check, not a load-test score.
- **Backend model:** default is a local model via Ollama/llama.cpp (true air-gap); the Anthropic API
  is an optional easy-mode. Either way Claude Code is the harness and the flow is identical.

## Layout
```
.claude-plugin/plugin.json   manifest (NO hooks field — hooks/hooks.json auto-loads)
skills/tutor/SKILL.md        the six-beat Socratic loop (teach → build → quiz-to-consolidate)
commands/                    the seven slash commands
hooks/                       session-start, title, guard (the jail)
bin/dojo.sh                  state helper (progress.json + steps.tsv)
curriculum/step-01..07.md    the steps (frame/teach/spine/checks/quizzes)
curriculum/steps.tsv         step → title/spine/kind table
curriculum/reference/        working, tested reference servers for every step + README
env/docs/build-bundle.sh     builds the offline docs bundle (process-family scoped)
env/docs/protocol-http1-cheatsheet.md   the parser contract (committed, complete)
env/bench/Gemfile,config.ru  the pinned gem set + the one Rack app every server serves
```

Built for the RubyConf 2026 concurrency talk, as a workshop pilot.
