# dojos

Tutored, constrained **coding-dojo plugins for Claude Code** — build real systems the hard
way, with a Socratic tutor that makes you type the load-bearing code yourself and an offline
jail that keeps you honest.

The `dojo` CLI lets you **start a dojo right away** or **install it** for use in any session.
Nothing is published anywhere — the tool runs straight from this clone.

## Install the CLI

You need `git`, `node` ≥ 18, and the `claude` CLI on your PATH.

```bash
gh repo clone geeksilva97/dojos ~/.dojos && ~/.dojos/install.sh
```

`install.sh` symlinks `dojo` onto your PATH (`~/.local/bin` by default) and tells you if that
dir isn't on your PATH yet. Re-run it any time to update (it `git pull`s and re-links).

## Use it

```bash
dojo list                          # what's available
dojo run demonkey ./my-workshop    # start now, in ./my-workshop — nothing installed
dojo install demonkey              # persistent: /demonkey:start works in any claude session
dojo update                        # pull the latest tool + dojos
```

- **`dojo run`** is the quickest way in: it launches Claude with the dojo loaded, offline jail
  on, in the project dir you name (created if needed). Close it and nothing lingers.
- **`dojo install`** registers the dojo as a native Claude Code plugin, so its slash commands
  (e.g. `/demonkey:start`) are available everywhere until you `dojo uninstall` it.

## The dojos

| Dojo | What you build |
|------|----------------|
| **demonkey** | Ruby web servers through the process family — raw socket → Unicorn-like preforking server with signals, graceful shutdown, USR2 restart. |
| **c10k-dojo** | Ruby web servers from raw sockets to C10K, graded against a constrained benchmark. |
| **reactor-dojo** | A single-threaded `IO.select` reactor that juggles thousands of connections. |
| **loopcraft** | An AI agent loop with tool calling in TypeScript — from a raw LLM call to a full agent with weather, search, and skills. |
| **systeminterview** | System design interviews — scope, architecture, deep dives, estimation, trade-offs using Alex Xu's framework. |
| **dojo-forge** | The generator: scaffold a brand-new dojo for any topic (`dojo new`). |

## Repo layout

```
dojos/
  c10k-dojo/        # C10K challenge dojo
  demonkey/          # Ruby process-family dojo
  reactor-dojo/      # IO.select reactor dojo
  loopcraft/          # AI agent loop dojo
  systeminterview/    # System design interview dojo
dojo-forge/           # Meta-plugin: generates new dojos
src/                  # dojo CLI source
bin/dojo.js           # CLI entry point
docs/ARCHITECTURE.md  # How it all fits together
```

All dojos live under `dojos/`. The `dojo-forge` generator stays at the root since it's a meta-plugin, not a dojo itself.

## Creating a new dojo

### Option 1: dojo-forge (recommended)

`dojo-forge` is a meta-plugin that generates a complete dojo from a topic. It has two modes:

**Self-service mode** — give it a topic and it researches + scaffolds automatically:

```bash
dojo new "a key-value store in Go"
```

**Interview mode** — it asks you questions about topic, language, progression, constraints:

```bash
dojo new
```

The forge generates:
- Curriculum steps (`step-01.md` through `step-NN.md`) with Socratic quizzes
- A tutor skill (7-beat loop: frame → teach → build → review → verify → quiz → next)
- Guard hooks (offline jail, spine-write protection)
- Per-project state tracking (`bin/dojo.sh`)
- Slash commands (`/start`, `/next`, `/hint`, `/reveal`, `/setup`, `/status`)
- A docs bundle builder for offline reference

### Option 2: manual

To create a dojo from scratch:

1. **Create the directory** under `dojos/`:

   ```bash
   mkdir -p dojos/my-dojo/.claude-plugin
   ```

2. **Add a plugin manifest** at `dojos/my-dojo/.claude-plugin/plugin.json`:

   ```json
   {
     "name": "my-dojo",
     "version": "0.1.0",
     "description": "A Socratic dojo for building X in Y",
     "author": "Your Name"
   }
   ```

   **Do not** add a `"hooks"` field — hooks auto-load from `hooks/hooks.json`; referencing it in the manifest causes errors.

3. **Register in marketplace** — add an entry to `.claude-plugin/marketplace.json`:

   ```json
   { "name": "my-dojo", "source": "./dojos/my-dojo", "category": "workshop" }
   ```

4. **Create the minimum structure**:

   ```
   dojos/my-dojo/
     .claude-plugin/plugin.json    # manifest (no "hooks" field!)
     curriculum/
       steps.tsv                   # step number, title, spine file, kind
       step-01.md                  # first curriculum step
       reference/                  # completed reference solutions
     hooks/
       hooks.json                  # event → script mappings
       session-start.sh            # seeds tutor context on session start
       guard.sh                    # offline jail + spine-write protection
     skills/tutor/SKILL.md         # the Socratic tutor skill
     commands/
       start.md                    # /my-dojo:start
       next.md                     # /my-dojo:next
       hint.md                      # /my-dojo:hint
       reveal.md                   # /my-dojo:reveal
       setup.md                    # /my-dojo:setup
       status.md                   # /my-dojo:status
     bin/dojo.sh                   # state helper (progress.json + steps.tsv)
     env/docs/                     # offline reference material (cheatsheets)
   ```

5. **Run the tests**:

   ```bash
   node --test   # verifies manifest name matches, no "hooks" field, plugin resolves
   ```

### What every dojo needs

| Component | Purpose |
|-----------|---------|
| **Curriculum steps** | Each step has a Frame (why), Teach (mechanisms), Spine (what learner types), Review, Success check, Consolidate (quiz) |
| **Tutor skill** | Drives the 7-beat Socratic loop; reads the current step, guides the learner |
| **Guard hook** | Blocks web access, external egress, and ad-hoc installs; blocks writing the spine file |
| **Session-start hook** | Seeds context: current step, spine file, setup status |
| **`bin/dojo.sh`** | Reads/writes `progress.json`, resolves current step from `steps.tsv` |
| **Docs bundle** | Offline reference material the learner can consult instead of the internet |

### Key conventions

- **Consolidation questions are free-text** — the learner types their understanding in their own words; the tutor scores 1–5, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense or vague answers do NOT count — no advancement without understanding
- **Fixed linear path** — the tutor always points to the one next step, never a menu
- **Type-the-spine guard** — a `PreToolUse` hook denies the agent writing the current spine file
- **Offline jail** — blocks `WebFetch`/`WebSearch` + external Bash egress; points at the `docs/` bundle
- **Given black boxes** — ship as complete committed cheatsheets, framed as `[scaffold]` GIVEN material
- **Per-project state** — `<project>/<.my-dojo>/progress.json`; a new folder starts fresh at Step 1

## Offline by design

Each dojo runs in a jail (a `WebFetch`/`WebSearch` block plus the plugin's own guard hooks),
so you work from a bundled docs bundle, not the internet. That's the point — the friction is
the lesson. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how it all fits together.

## Running the tests

```bash
node --test                              # the whole suite
node --test test/cli.test.js             # one file
```

The suite never launches a real Claude session: a stub `claude` on `PATH` records the exact
command, and every test runs in an isolated temp sandbox. Bash hook/state tests are skipped on
Windows.