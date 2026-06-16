# loopcraft

A **Socratic tutor** that teaches you how AI agents work by making you build one — from a raw LLM call
to a full agent loop with tool calling, in TypeScript. You type the load-bearing code yourself.

No frameworks. No npm packages. No transpiler. Just **TypeScript native features** — Node 22+ runs
`.ts` files directly, and built-in `fetch` talks to Ollama and APIs. You learn the actual mechanisms,
not a wrapper.

## Prerequisites

- **Node.js 22+** (runs `.ts` files natively — no tsx, no transpiler, no npm packages)
- **Ollama** (local LLM, any model — `qwen3:8b` suggested)
- **Open-Meteo** (free weather API, no key needed)
- **DuckDuckGo** (free search, no key needed)

## Install

```bash
# Make sure Ollama is running and you have a model:
ollama pull qwen3:8b    # or any model you prefer

# No npm packages needed — Node 22+ runs TypeScript natively.
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

## Run your agent

```bash
ollama create loopcraft -f workspace/Modelfile    # Build the model (once, then after edits)
node workspace/agent.ts                             # Run your agent
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
│       ├── Modelfile            final reference Modelfile
│       └── skills/              example skills for Step 7
├── env/docs/                    offline cheatsheets (built into docs/ by /setup)
├── hooks/                       session-start, title, guard (offline jail)
├── loopcraft.sh                 launch script
├── skills/tutor/SKILL.md        the Socratic tutor
└── README.md                    this file
```

## License

MIT