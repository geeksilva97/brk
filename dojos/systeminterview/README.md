# systeminterview

A **Socratic tutor** that simulates a system design interview — you practice designing
Google Meet (video conferencing) from scoping to wrap-up, while the tutor plays the
interviewer. You type the load-bearing design documents yourself.

No frameworks. No code. Just **design thinking** — scoping, architecture, deep dives,
estimation, and trade-offs. You learn the actual patterns interviewers look for, not
templates to memorize.

## What you'll design

A video conferencing system (like Google Meet) covering:

| Step | What you design | Key concept |
|------|-----------------|-------------|
| 1 | Scope & requirements | Clarifying questions, functional/non-functional requirements |
| 2 | High-level architecture | Signaling, media, data flows, component responsibilities |
| 3 | Signaling & WebRTC | SDP offer/answer, ICE, DTLS, reconnection |
| 4 | Media servers & NAT | SFU vs MCU vs mesh, STUN/TURN, bandwidth math |
| 5 | Capacity estimation | Back-of-envelope math, server counts, TURN costs |
| 6 | Recording, multi-region & trade-offs | Async pipelines, GeoDNS, trade-off analysis |
| 7 | Wrap-up & evaluation | Bottlenecks, improvements, 60-second summary |

## Prerequisites

- Software engineering experience (2+ years)
- Basic networking (HTTP, TCP, DNS)
- No distributed systems expertise required — the tutor teaches what you need

## Install

No runtime dependencies. This is a design interview dojo — you write documents, not code.

## Use

```bash
# Start the dojo (creates a project dir or uses current dir):
./systeminterview.sh ~/my-workshop

# Inside Claude Code, the tutor will guide you step by step:
/systeminterview:setup     # one-time setup (create workspace/, build docs bundle)
/systeminterview:start    # begin from Step 1
/systeminterview:next      # advance to the next step
/systeminterview:status    # show current progress
/systeminterview:hint      # get a hint for the current step
/systeminterview:reveal    # see the reference design (last resort)
```

## What you write vs. what's provided

You write **design documents** in `workspace/`:
- `scope.md` — requirements and assumptions
- `architecture.md` — component diagram and data flows
- `signaling.md` — WebRTC signaling flow
- `media-servers.md` — topology comparison and NAT traversal
- `capacity.md` — estimation with math
- `tradeoffs.md` — recording, multi-region, trade-off analysis

**Provided as reference** (you don't derive these):
- `docs/webrtc-cheatsheet.md` — WebRTC fundamentals, protocol details, key numbers
- `docs/capacity-cheatsheet.md` — estimation framework, reference numbers, worked example

## Layout

```
systeminterview/
├── .claude-plugin/plugin.json   manifest
├── bin/dojo.sh                  state helper (progress.json + steps.tsv)
├── commands/                    start, next, status, hint, reveal, setup
├── curriculum/
│   ├── steps.tsv                step number → title → spine → kind
│   ├── step-01.md … step-07.md the 7 steps
│   └── reference/
│       └── ground-truth.md      complete reference design (evaluation)
├── env/docs/                    offline cheatsheets (built into docs/ by /setup)
├── hooks/                       session-start, title, guard (offline jail)
├── systeminterview.sh           launch script
├── skills/tutor/SKILL.md       the Socratic tutor
└── README.md                    this file
```

Workspace (created by setup, learner edits here):
```
workspace/
├── scope.md           learner edits (Step 1)
├── architecture.md    learner edits (Step 2)
├── signaling.md       learner edits (Step 3)
├── media-servers.md   learner edits (Step 4)
├── capacity.md        learner edits (Step 5)
└── tradeoffs.md       learner edits (Step 6)
```

## How it's wired

- **Hooks are the jail.** `PreToolUse` denies `WebFetch`/`WebSearch` and external Bash egress, and
  blocks the agent from writing the current step's *spine* file (you type that). It also blocks
  reading the ground truth directly (use `/systeminterview:reveal`). `SessionStart` resumes you
  at your step and injects its curriculum. `UserPromptSubmit` keeps the title in sync.
- **State** is per-project: `<project>/.systeminterview/progress.json` (keyed to the folder
  you're in, so a new folder starts fresh at Step 1; survives sessions within that project).
- **Backend model:** default is a local model via Ollama/llama.cpp (true air-gap); the Anthropic API
  is an optional easy-mode. Either way Claude Code is the harness and the flow is identical.

## License

MIT