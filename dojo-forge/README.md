# dojo-forge

A **meta-plugin** for Claude Code that generates tutored **coding-dojo** plugins for workshops — on
any topic. Run one command and dojo-forge scaffolds a complete, loadable dojo plugin shaped exactly
like the reference `c10k-dojo`: a Socratic tutor that quizzes the learner, makes them **type the
load-bearing code themselves**, and enforces an offline jail through hooks.

You give it a subject — "a reactor-based server", "a Ruby C extension", "writing a parser" — and it
produces a `<topic>-dojo/` plugin with its own curriculum, jail, per-project state, and slash
commands.

## Use it

```bash
claude --plugin-dir ./dojo-forge
/dojo-forge:new            # interview mode: answer questions, scaffold a new dojo
/dojo-forge:new a key-value store in Go   # self-service mode: research + scaffold
```

### Interview mode (no arguments)

The interview (all via the `AskUserQuestion` tool) gathers:
- **topic / subject** and **language / runtime** (default Ruby),
- the **plugin name** (default kebab `<topic>-dojo`),
- the **spine progression** — 4–12 milestones, each with its concept, the spine the learner types,
  and a success check,
- the **constraint / jail** — offline? which docs to mount? which deps are pinned/forbidden?
- the **win-condition** — how each step is graded (a runnable check; measurement optional),
- the **given black boxes** — what the learner is handed as a cheatsheet vs. must derive.

### Self-service mode (topic as argument)

When you provide a topic, dojo-forge uses `WebSearch` to research the domain and synthesizes the
curriculum automatically — spine progression, quizzes, gotchas, cheatsheets, and jail constraints.
You don't need to be an expert on the topic; the forge figures out the learning path, the common
pitfalls, and the natural progression from scratch.

One confirmation step: the forge presents a compact spec (plugin name, topic, language, the numbered
ramp with spine files + checks, the jail, the cheatsheets) and waits for your "looks good" before
scaffolding. Then it's fully automatic.

This means **anyone can generate a dojo on a topic they want to learn** — no domain expertise
required. The forge researches for you, and the generated tutor teaches you.

## How the generation works

dojo-forge ships two halves:

- **`templates/`** — the generic, reusable dojo skeleton. The tutor skill (the 7-beat Socratic
  loop), all hooks (session-start, title, guard), `bin/dojo.sh`, the commands, the docs-bundle
  builder, the step format, and the gitignore — every topic-agnostic piece, with `{{PLACEHOLDER}}`
  markers. All the hard-won fixes from c10k-dojo are baked in here, so every generated dojo inherits
  them.
- **`skills/forge/SKILL.md` + `commands/new.md`** — the generator. In interview mode it asks
  questions; in self-service mode it uses `WebSearch` to research the topic. Both modes converge on
  the same scaffold: they compute placeholder values, copy templates with substitutions, and write
  the **topic-specific** parts: `curriculum/steps.tsv`, the `step-NN.md` files, a tailored `/setup`,
  the cheatsheets, and a README.

### Placeholder scheme
Templates use `{{NAME}}` markers. The load-bearing ones:

| Placeholder | Meaning | Example |
|---|---|---|
| `{{PLUGIN_NAME}}` | kebab plugin name | `reactor-dojo` |
| `{{STATE_DIR}}` | per-project state dir | `.reactor-dojo` |
| `{{TOPIC}}` | human-readable subject | `a reactor-based server` |
| `{{TOPIC_DESCRIPTION}}` | manifest description | (one sentence) |
| `{{LANGUAGE}}` / `{{RUNTIME_CMD}}` | language + run command | `Ruby` / `ruby` |
| `{{AUTHOR}}` | manifest author | `Antonio Barbosa` |
| `{{KEYWORDS}}` | manifest keywords (JSON array) | `["ruby","reactor",…]` |
| `{{FIRST_SPINE}}` | step 1's spine file | `workspace/reactor.rb` |
| `{{DEPS_HINT}}` | dependency-install denial hint | `The set is stdlib-only.` |
| `{{SETUP_DEPS}}` / `{{SETUP_EXTRA}}` | `/setup` provisioning steps | (topic-specific) |
| `{{BUNDLE_GATHER}}` / `{{INDEX_BODY}}` | docs-bundle gathering + index | (topic-specific) |

The `step-template.md` placeholders (`{{STEP_TITLE}}`, `{{DIAGNOSE_QUESTION}}`, …) document the step
format; generated step files are authored, not templated, so they carry no leftover placeholders.

## What every generated dojo inherits

The same battle-tested wiring as c10k-dojo:

- **Manifest has no `"hooks"` field** (hooks/hooks.json auto-loads; referencing it errors).
- **Per-project state** in `<project>/<STATE_DIR>/progress.json` — a new folder starts fresh at Step 1.
- **Title sync** via `SessionStart` (seed) + `UserPromptSubmit` (re-title only when the step changed).
- **Consolidation questions are free-text** — the learner types their understanding in their own words; the tutor scores 1–5, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense or vague answers do NOT count — no advancement without understanding..
- **Fixed linear path** — the tutor always points to the one next step, never a menu.
- **Type-the-spine guard** — a `PreToolUse` hook denies the agent writing the current spine file.
- **Offline jail** — a `PreToolUse` hook denies WebFetch/WebSearch + external Bash egress + ad-hoc
  dependency installs; points at the mounted `docs/` bundle.
- **`/setup` provisions deps locally before jailing**, so the learner works offline afterward.
- **Given black boxes ship as complete committed cheatsheets**, framed as `[scaffold]` GIVEN material.
- **Root launcher `<PLUGIN_NAME>.sh`** — a one-shot `exec claude --plugin-dir …` wrapper the learner
  runs from any project dir. It disables web tools + prompt suggestions at the CLI level (the latter
  must be set before claude launches — a hook is too late), so the learner can't accidentally break
  the jail or get hand-out suggestions. Documented as the primary entrypoint in every generated README.

## Layout
```
.claude-plugin/plugin.json   manifest (no "hooks" field)
commands/new.md              /dojo-forge:new — the entrypoint
skills/forge/SKILL.md        the generator: interview or research + scaffold logic
templates/                   the generic dojo skeleton (placeholdered)
  .claude-plugin/plugin.json
  skills/tutor/SKILL.md       the 7-beat Socratic loop
  hooks/                      hooks.json, session-start, title, guard
  bin/dojo.sh                 state helper (progress.json + steps.tsv)
  commands/                   start, next, status, hint, reveal, setup
  curriculum/step-template.md the step format spec
  env/docs/build-bundle.sh    offline docs-bundle builder
  launch.sh.tmpl              root launcher (→ <PLUGIN_NAME>.sh)
  gitignore.tmpl
```

Examples of generated dojos live in the repo's `dojos/` directory (reactor-dojo, loopcraft, etc.).
Run `dojo list` to see all available dojos including examples.