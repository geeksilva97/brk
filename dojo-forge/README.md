# dojo-forge

A **meta-plugin** for Claude Code that generates tutored **coding-dojo** plugins for workshops — on
any topic. Run one command, answer an interview, and dojo-forge scaffolds a complete, loadable dojo
plugin shaped exactly like the reference `c10k-dojo`: a Socratic tutor that quizzes the learner,
makes them **type the load-bearing code themselves**, and enforces an offline jail through hooks.

You give it a subject — "a reactor-based server", "a Ruby C extension", "writing a parser" — and it
produces a `<topic>-dojo/` plugin with its own curriculum, jail, per-project state, and slash
commands.

## Use it

```bash
claude --plugin-dir ./dojo-forge
/dojo-forge:new            # interview + scaffold a new dojo
# (optionally seed the topic)
/dojo-forge:new a reactor-based server in Ruby
```

The interview (all via the `AskUserQuestion` tool) gathers:
- **topic / subject** and **language / runtime** (default Ruby),
- the **plugin name** (default kebab `<topic>-dojo`),
- the **spine progression** — 4–12 milestones, each with its concept, the spine the learner types,
  and a success check,
- the **constraint / jail** — offline? which docs to mount? which deps are pinned/forbidden?
- the **win-condition** — how each step is graded (a runnable check; measurement optional),
- the **given black boxes** — what the learner is handed as a cheatsheet vs. must derive.

Then it writes `./<name>-dojo/`, validates it with `claude plugin validate`, and reports.

## How the generation works

dojo-forge ships two halves:

- **`templates/`** — the generic, reusable dojo skeleton. The tutor skill (the 7-beat Socratic
  loop), all hooks (session-start, title, guard), `bin/dojo.sh`, the commands, the docs-bundle
  builder, the step format, and the gitignore — every topic-agnostic piece, with `{{PLACEHOLDER}}`
  markers. All the hard-won fixes from c10k-dojo are baked in here, so every generated dojo inherits
  them.
- **`skills/forge/SKILL.md` + `commands/new.md`** — the generator. It runs the interview, computes
  the placeholder values, copies the templates with substitutions, and writes the **topic-specific**
  parts: `curriculum/steps.tsv`, the `step-NN.md` files, a tailored `/setup`, the cheatsheets, and a
  README.

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
- **Quizzes are `AskUserQuestion` calls** (✅ correct + ❌ misconception distractors), never prose.
- **Fixed linear path** — the tutor always points to the one next step, never a menu.
- **Type-the-spine guard** — a `PreToolUse` hook denies the agent writing the current spine file.
- **Offline jail** — a `PreToolUse` hook denies WebFetch/WebSearch + external Bash egress + ad-hoc
  dependency installs; points at the mounted `docs/` bundle.
- **`/setup` provisions deps locally before jailing**, so the learner works offline afterward.
- **Given black boxes ship as complete committed cheatsheets**, framed as `[scaffold]` GIVEN material.

## Layout
```
.claude-plugin/plugin.json   manifest (no "hooks" field)
commands/new.md              /dojo-forge:new — the entrypoint
skills/forge/SKILL.md        the generator: interview + scaffold logic
templates/                   the generic dojo skeleton (placeholdered)
  .claude-plugin/plugin.json
  skills/tutor/SKILL.md       the 7-beat Socratic loop
  hooks/                      hooks.json, session-start, title, guard
  bin/dojo.sh                 state helper (progress.json + steps.tsv)
  commands/                   start, next, status, hint, reveal, setup
  curriculum/step-template.md the step format spec
  env/docs/build-bundle.sh    offline docs-bundle builder
  gitignore.tmpl
examples/reactor-dojo/        a generated example (proof it works)
```

## Example output
`examples/reactor-dojo/` is a complete dojo generated by this tool for "a reactor-based server in
Ruby" (event-loop / `IO.select`). It passes `claude plugin validate`. Use it as a reference for what
the interview produces.

Built for the RubyConf 2026 concurrency talk's workshop tooling.
