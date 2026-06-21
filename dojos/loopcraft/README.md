# loopcraft

A **Socratic tutor** that teaches you how AI agents work by making you build one — from a raw LLM call
to a full agent loop with tool calling, in TypeScript. You type the load-bearing code yourself.

No frameworks. No npm packages. No transpiler. Just **TypeScript native features** — Node 22+ runs
`.ts` files directly, and built-in `fetch` talks to Ollama and APIs. You learn the actual mechanisms,
not a wrapper.

## Stack

- **Node.js 22+** (runs `.ts` files natively — no tsx, no transpiler, no npm packages)
- **Ollama** (local LLM, any model — `llama3:8b` suggested)
- **Open-Meteo** (free weather API, no key needed)
- **DuckDuckGo** (free search, no key needed)

## Prerequisites

- **Node.js 22+** — TypeScript runs natively. Node 22–23.5 needs `--experimental-strip-types`; Node 23.6+ needs no flags.
- **Ollama** — installed and running with a model pulled

> **Two uses of Ollama — don't conflate them.** The agent *you build* calls a local model via
> Ollama (the prerequisite above). Separately, Claude Code — the *tutor* — can itself run on a
> local model for a true air-gap: launch with `--model llama3:8b` (the `loopcraft.sh` wrapper
> forwards it; Ollama serves on `:11434`), or use the Anthropic API as easy-mode. Record the choice
> with `dojo.sh set-mode <local-jailed|anthropic-api>`.

## Install

```bash
# Make sure Ollama is running and you have a model:
ollama pull llama3:8b    # or any model you prefer

# No npm packages needed — Node 22+ runs TypeScript natively.
# Optional (IDE IntelliSense only, not required to run):
npm i -D @types/node
```

## Use

```bash
# Start the dojo (creates a project dir or uses current dir):
./loopcraft.sh ~/my-workshop

# Inside Claude Code, the tutor will guide you step by step:
/loopcraft:start     # begin from Step 1
/loopcraft:next      # advance to the next step
/loopcraft:status    # show current progress
/loopcraft:hint      # get a hint for the current step
/loopcraft:reveal    # see the reference solution (last resort)
```

## The 7 steps

| Step | What you build | Key concept |
|------|---------------|-------------|
| 1 | Ollama + Modelfile | Raw chat call, system prompts baked in |
| 2 | Tool definitions | `[TOOL: ...]` in the Modelfile, model emits JSON |
| 3 | Parse + execute weather | Extract tool calls, call Open-Meteo API |
| 4 | Inject + re-prompt | Feed tool result back, model answers naturally |
| 5 | The agent loop | `while` loop until model answers without tools |
| 6 | Web search tool | DuckDuckGo via fetch, model picks which tool |
| 7 | Skills as tools | Scan `skills/`, dynamic descriptions, load SKILL.md |

## What you write vs. what's provided

You write **only `workspace/agent.ts`** — the agent loop. All utility functions (`chat`, `parseToolCalls`,
`getWeather`, `searchWeb`, `loadSkill`, `scanSkills`, `COORDINATES`, `executeTool`) are provided in
**`workspace/utils.ts`** (scaffolding, copied during setup). You import and call them; you don't edit them.

## Run your agent

```bash
ollama create loopcraft -f workspace/Modelfile    # Build the model (once, then after edits)

# Node 22–23.5:
node --experimental-strip-types workspace/agent.ts

# Node 23.6+:
node workspace/agent.ts
```

## Layout

```
loopcraft/
├── .claude-plugin/plugin.json   manifest
├── bin/dojo.sh                  state helper (progress.json + steps.tsv)
├── commands/                    start, next, status, hint, reveal, setup
├── curriculum/
│   ├── steps.tsv                step number → title → spine → kind
│   ├── step-01.md … step-07.md  the 7 steps
│   └── reference/
│       ├── agent.ts             final reference implementation
│       ├── utils.ts             final reference utilities
│       ├── Modelfile            final reference Modelfile
│       └── skills/              example skills for Step 7
├── env/docs/                    offline cheatsheets (built into docs/ by /setup)
├── hooks/                       session-start, title, guard (offline jail)
├── loopcraft.sh                 launch script
├── skills/tutor/SKILL.md        the Socratic tutor
└── README.md                    this file
```

Workspace (created by setup, learner edits here):
```
workspace/
├── Modelfile       learner edits (Steps 1–2)
├── utils.ts        PROVIDED — scaffolding (chat, parseToolCalls, getWeather, etc.)
└── agent.ts        learner writes this (Steps 3–7)
```

## License

MIT