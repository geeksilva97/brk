# systeminterview

A **Socratic tutor** that simulates a system design interview — you practice designing
Google Meet (video conferencing) from scoping to wrap-up, entirely through conversation.
No files. No code. Just **dialogue** — exactly like a real interview.

## What you'll design

A video conferencing system (like Google Meet) covering:

| Step | What you discuss | Key concept |
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

No runtime dependencies. This is a conversation dojo — you talk, not code.

## Use

```bash
# Start the dojo (creates a project dir or uses current dir):
./systeminterview.sh ~/my-workshop

# Inside Claude Code, the tutor will guide you step by step:
/systeminterview:setup     # one-time setup (create state dir)
/systeminterview:start    # begin from Step 1
/systeminterview:next      # advance to the next step
/systeminterview:status    # show current progress
/systeminterview:hint      # get a hint for the current step
/systeminterview:reveal    # see the reference design (last resort)
```

## How it works

This is a **conversation-first** dojo — there are no files to write, no workspace to
manage. The learner discusses their design choices verbally, and the tutor (playing
the interviewer) probes, challenges, and advances them when they demonstrate understanding.
This mirrors how real system design interviews work: it's a dialogue, not a document.

**The tutor:**
- Frames each step's problem
- Teaches new concepts before the learner needs them
- Asks the learner to describe their design verbally
- Probes and challenges weak spots
- Asks consolidation questions (free-text, scored 1-5)
- Advances when understanding is demonstrated

**Hooks enforce:**
- No web access (the dojo is offline by design — use first principles and reference material)
- No dependency installs (this is a design interview, not a coding exercise)
- Step tracking via per-project `.systeminterview/progress.json`
- Title sync with current step

## Layout

```
systeminterview/
├── .claude-plugin/plugin.json   manifest
├── bin/dojo.sh                  state helper (progress.json + steps.tsv)
├── commands/                    start, next, status, hint, reveal, setup
├── curriculum/
│   ├── steps.tsv                step number → title → kind
│   ├── step-01.md … step-07.md the 7 steps
│   └── reference/
│       ├── ground-truth.md      complete reference design (evaluation)
│       ├── webrtc-cheatsheet.md WebRTC fundamentals + key numbers
│       └── capacity-cheatsheet.md estimation framework + reference numbers
├── hooks/                       session-start, title, guard (offline jail)
├── systeminterview.sh           launch script
├── skills/tutor/SKILL.md       the Socratic tutor
└── README.md                    this file
```

## License

MIT