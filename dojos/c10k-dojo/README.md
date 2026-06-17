# c10k-dojo

A Claude Code **plugin** that tutors you into building Ruby web servers from raw sockets all the way
to one that beats the **C10K problem** — under a deliberate constraint (no web access; you reason
from a mounted Ruby + C docs bundle and first principles).

Claude Code acts as a **Socratic tutor**: it frames each problem, quizzes you with
free-text questions (scored 1–5), reasons about whether your explanation covers the key concepts, and makes **you type the load-bearing
code** while it handles boilerplate and review. Every server is graded against a cgroup-constrained
benchmark, so you *feel* where fork, threads, and fibers each live and die.

## Install (local dev)

```bash
# One-shot launcher (disables web + prompt suggestions at the CLI level):
./c10k-dojo.sh ~/my-workshop     # create/enter that dir and run the dojo there
# …or the bare claude path:
claude --plugin-dir ./c10k-dojo
# then, in the project where you'll build:
/c10k-dojo:setup     # build the offline docs bundle + benchmark image
/c10k-dojo:start     # begin (or resume) at your current step
```

## Commands
- `/c10k-dojo:start` — begin/resume the current step's tutored loop
- `/c10k-dojo:next` — advance after the success check + explain-it-back gate
- `/c10k-dojo:bench` — stress the current server in the constrained cage, record results
- `/c10k-dojo:status` — progress + results table + the connections-vs-survival "money chart"
- `/c10k-dojo:hint` — a scoped nudge that never reveals the full spine
- `/c10k-dojo:reveal` — instructor escape hatch: show the reference impl
- `/c10k-dojo:setup` — one-time environment setup

## How it's wired
- **Hooks are the jail.** `PreToolUse` denies `WebFetch`/`WebSearch` and external Bash egress, and
  blocks the agent from writing the current step's *spine* file (you type that). `SessionStart`
  resumes you at your step and injects its curriculum. `PostToolUse` captures benchmark rows.
- **State** is per-project: `<project>/.c10k-dojo/progress.json` + `results.csv` (keyed to the folder
  you're in, so a new folder starts fresh at Step 1; survives sessions within that project).
- **Backend model:** default is a local model via Ollama/llama.cpp (true air-gap); the Anthropic API
  is an optional easy-mode. Either way Claude Code is the harness and the flow is identical.

## Layout
```
.claude-plugin/plugin.json   manifest
c10k-dojo.sh                 launch script (one-shot: disables web + prompt suggestions)
skills/tutor/SKILL.md        the 7-beat Socratic loop
commands/                    the seven slash commands
hooks/                       session-start, guard (jail), post-bench
bin/dojo.sh                  state helper (progress.json + steps.tsv)
curriculum/step-01..17.md    the steps (frame/quizzes/spine/checks)
curriculum/steps.tsv         step → title/spine/kind table
env/docs/build-bundle.sh     builds the offline docs bundle
env/bench/                   Dockerfile.target, holder.go (capacity), run.sh, config.ru, Gemfile
                             (throughput/latency via ab; probe.go kept as a Go-only fallback)
env/ai-jail.toml             optional OS-level isolation template
```

Built for the RubyConf 2026 concurrency talk. The 20-chapter source workshop is in
`../outline.md` + `../notes/`.
