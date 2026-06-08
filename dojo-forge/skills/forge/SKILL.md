---
name: forge
description: Interview a workshop instructor and scaffold a complete, loadable tutored coding-dojo plugin for any topic — copying the generic dojo templates, substituting placeholders, and generating a topic-tailored curriculum. Use when the instructor runs /dojo-forge:new or asks to create/generate a new dojo plugin for a subject.
---

# dojo-forge — the dojo generator

You generate **tutored coding-dojo plugins** — Claude Code plugins shaped exactly like the reference
`c10k-dojo`: a Socratic tutor that quizzes the learner, makes them type the load-bearing "spine" code
themselves, and enforces an offline jail through hooks. Most of a dojo is topic-agnostic and lives as
templates in `${CLAUDE_PLUGIN_ROOT}/templates/`. Your job is to (1) interview the instructor, (2) copy
those templates with placeholders substituted, and (3) generate the topic-specific curriculum.

You run in two phases: **INTERVIEW**, then **SCAFFOLD**.

---

## Phase 1 — INTERVIEW (all via the AskUserQuestion tool)

Ask in this order. **Every question is an `AskUserQuestion` tool call** with good options plus an
"Other" free-text path — never plain-text questions. Group related questions into one Ask (the tool
supports up to 4 questions per call) where it reads naturally. Carry answers forward as defaults.

1. **Topic / subject** — what the learner builds (free text via "Other"; offer a few examples like
   "a reactor / event-loop server", "a Ruby C extension", "a parser / interpreter", "a key-value
   store"). This is `{{TOPIC}}`.

2. **Language / runtime** — default **Ruby**; offer common alternatives. This is `{{LANGUAGE}}` and
   sets `{{RUNTIME_CMD}}` (e.g. `ruby`, `node`, `python`) and `{{DEPS_HINT}}` /package manager.

3. **Plugin name** — propose a default kebab-case `<topic-slug>-dojo` and let them confirm or
   override. This is `{{PLUGIN_NAME}}`; derive `{{STATE_DIR}}` = `.<plugin-name>`.

4. **The spine progression** — the heart of it. Elicit **4–12 milestones**, each being one step the
   learner builds. For EACH milestone capture: the concept it teaches, the spine (the file the
   learner types + roughly what lines), and the success check. Do this conversationally but
   confirm the final ordered list with one Ask ("Here's the ramp — good, or reorder/add/drop?"). The
   ordering must be a single fixed line where each step builds on the previous.

5. **The constraint / jail** — one Ask covering: offline (block web)? which docs to mount? which
   dependencies are pinned/forbidden? This drives the guard hook message and the `/setup` deps step.

6. **The win-condition / grading** — how a step is graded: a runnable check command per step
   (always), and optionally a benchmark/measurement. Capture the per-step `success check` and
   whether a measurement harness is needed (if yes, note it for the README — the template ships the
   guards + tutor regardless; a bench harness is an add-on the instructor can flesh out later).

7. **The given black box(es)** — what is the learner NOT expected to know up front and therefore
   GIVEN as a complete committed cheatsheet (scaffold), vs. what they must derive (the spine). For
   each black box, note a `<thing>-cheatsheet.md` to ship in `env/docs/`.

After the interview, **echo back a compact spec** (plugin name, topic, language, the numbered ramp
with spine files + checks, the jail, the cheatsheets) and get a final confirmation Ask before writing.

---

## Phase 2 — SCAFFOLD (materialize the plugin)

Write the new plugin into the current project at `./<PLUGIN_NAME>/` (or wherever the instructor asked).
**Procedure:**

### 2a. Compute the placeholder values
Build a substitution map from the answers:

| Placeholder | Value |
|---|---|
| `{{PLUGIN_NAME}}` | kebab name, e.g. `reactor-dojo` |
| `{{STATE_DIR}}` | `.<plugin-name>`, e.g. `.reactor-dojo` |
| `{{TOPIC}}` | human topic, e.g. `a reactor-based server` |
| `{{TOPIC_DESCRIPTION}}` | one-sentence manifest description (mention Socratic tutor + type-the-spine + jail) |
| `{{LANGUAGE}}` | e.g. `Ruby` |
| `{{RUNTIME_CMD}}` | e.g. `ruby` |
| `{{AUTHOR}}` | instructor name (ask or default to the repo's git user) |
| `{{KEYWORDS}}` | JSON array, e.g. `["ruby","reactor","event-loop","workshop","tutor"]` |
| `{{FIRST_SPINE}}` | **step 1's spine file** (must match `steps.tsv` row 1's spine col), e.g. `workspace/blocking_echo.rb` |
| `{{DEPS_HINT}}` | one sentence naming the pinned deps, e.g. `The set is stdlib-only.` |

### 2b. Copy the generic skeleton verbatim, substituting placeholders
From `${CLAUDE_PLUGIN_ROOT}/templates/`, copy into `./<PLUGIN_NAME>/`:
- `.claude-plugin/plugin.json`
- `skills/tutor/SKILL.md`
- `hooks/hooks.json`, `hooks/session-start.sh`, `hooks/title.sh`, `hooks/guard.sh`
- `bin/dojo.sh`
- `commands/start.md`, `next.md`, `status.md`, `hint.md`, `reveal.md`, `setup.md`
- `env/docs/build-bundle.sh`
- `gitignore.tmpl` → write as `./<PLUGIN_NAME>/.gitignore`

Substitute **every** `{{...}}` placeholder in every copied file. The simplest reliable way: read each
template, replace placeholders in memory, and Write the result to the destination. Do a final
`grep -rl '{{' ./<PLUGIN_NAME>` and resolve any leftover placeholders.

For `commands/setup.md`, fill `{{SETUP_DEPS}}` with the concrete provisioning steps for this topic
(e.g. "stdlib only — nothing to install" for a pure-Ruby reactor, or the vendored Gemfile/bundle
steps for a gem-based topic) and `{{SETUP_EXTRA}}` with any extra setup bullets (or empty).

For `hooks/guard.sh`, the `{{DEPS_HINT}}` substitution tunes the dependency-install denial message.

For `env/docs/build-bundle.sh`, fill `{{BUNDLE_GATHER}}` with the topic's doc-gathering commands
(e.g. `ri` dumps + `man` pages for Ruby sockets; or a generated language reference) and
`{{INDEX_BODY}}` with a greppable INDEX table pointing at the bundled files + cheatsheets.

### 2c. Ensure executables
`chmod +x` the four scripts: `hooks/session-start.sh`, `hooks/title.sh`, `hooks/guard.sh`,
`bin/dojo.sh`, `env/docs/build-bundle.sh`.

### 2d. Generate the curriculum
Create `./<PLUGIN_NAME>/curriculum/`:

- **`steps.tsv`** — one TAB-separated row per milestone, NO header:
  `<step_num>\t<title>\t<spine_file>\t<kind>`
  Use `-` as the spine for steps with no learner-typed file (pure-concept/measurement steps); the
  state helper maps `-` to `workspace/`. `kind` is a short tag you choose (e.g. `concept`, `build`,
  `check`). Make sure columns are real tab characters, not spaces.

- **`step-NN.md`** (zero-padded) — one per milestone, following the format in
  `${CLAUDE_PLUGIN_ROOT}/templates/curriculum/step-template.md`. Fill EVERY section with real,
  topic-specific content derived from the interview:
  - **Frame** (1–3 sentences: the problem + why the previous step is inadequate),
  - **Diagnose-quiz**: a real question, ✅ correct answer with the nuance, and ❌ distractors that are
    genuine misconceptions for this topic (each with the targeted correction),
  - **Design-quiz**: same shape, about how to structure the fix,
  - **GIVEN black box** note IF this step relies on a cheatsheet (else drop the section),
  - **Spine**: exactly what the learner types, the primitives, and `Read first:` docs,
  - **Agent role**: `[explain]` / `[glue]` / `[scaffold]` / `[review]` lines (drop any that don't
    apply, but keep at least `[explain]` and `[review]`),
  - **Gotchas**: the classic bugs,
  - **Success check**: the runnable command(s) + expected output (the win-condition for this step),
  - **Reflect-quiz**: a comprehension check with ✅/❌ options,
  - **Next step**: name the single next step; never offer a branch.

  The LAST step's "Next step" should congratulate and point at `/{{PLUGIN_NAME}}:status` instead of a
  next step. Do NOT leave any `{{...}}` placeholders in generated step files — they're authored, not
  templated.

- **`curriculum/reference/`** (optional) — if you wrote any reference implementations or starter
  stubs, put them here and point each step's front-matter `reference:` at them. Otherwise set
  `reference:` to `-` and the `/reveal` command degrades gracefully.

### 2e. Ship the cheatsheets (the GIVEN black boxes)
For each black box from interview Q7, write a **complete, committed** cheatsheet to
`./<PLUGIN_NAME>/env/docs/<thing>-cheatsheet.md`. It must be a real worked example the learner can
copy the *shape* of — this is GIVEN scaffolding, framed in the relevant step as provided, not derived.
`build-bundle.sh` copies every `*-cheatsheet.md` next to it into the learner's `docs/` automatically.

### 2f. README
Write `./<PLUGIN_NAME>/README.md` from the c10k-dojo README's shape: what it teaches, install
(`claude --plugin-dir ./<PLUGIN_NAME>`), the `/setup` then `/start` flow, the command list, how it's
wired (hooks = jail, per-project state in `<STATE_DIR>/`), and the layout tree.

### 2g. Validate and report
Run, from the project dir:
- `claude plugin validate ./<PLUGIN_NAME>` → must print "Validation passed".
- `bash -n` on every `.sh` file under the new plugin.
- If `{{LANGUAGE}}` is Ruby and you wrote reference `.rb` files, `ruby -c` each.
- `grep -rl '{{' ./<PLUGIN_NAME>` → must be empty.

Report: the file tree, validation results, the placeholder values used, and any decisions/limitations
(e.g. "no benchmark harness generated — the success checks are runnable commands; add a bench/ dir
later if you want graded measurement").

---

## Invariants every generated dojo MUST satisfy (do not regress these)
1. The manifest has **no `"hooks"` field** — `hooks/hooks.json` auto-loads; referencing it causes a
   "Duplicate hooks file" error.
2. State is **per-project** in `${CLAUDE_PROJECT_DIR:-$PWD}/<STATE_DIR>/progress.json` — never global.
3. Title sync: `SessionStart` seeds the title + cache; `UserPromptSubmit` re-titles **only when the
   step changed**; no-op outside the project. Only those two events set the title.
4. All quizzes (diagnose/design/reflect) are `AskUserQuestion` calls with ✅ correct + ❌ misconception
   options — never plain text.
5. Fixed linear path — the tutor never offers a "pick what to build" menu; always one next step.
6. Type-the-spine `PreToolUse` guard denies writing the current step's spine file; glue/scaffold ok.
7. Offline jail `PreToolUse` guard denies WebFetch/WebSearch + external Bash egress.
8. `/setup` provisions deps locally BEFORE jailing, so the learner works offline afterward.
9. Anything the learner isn't expected to know is a complete committed cheatsheet, framed as GIVEN
   with a `[scaffold]` agent role.
10. The `SessionStart` hook injects the current step's curriculum + tutor directive as
    additionalContext and sets the title.
11. `bin/dojo.sh` (get/spine/title/kind/mode/set-mode/advance/status) reads a TAB-separated
    `steps.tsv`, no jq.
12. The `step-NN.md` format: frame / diagnose-quiz / design-quiz / spine / agent-role / gotchas /
    success-check / reflect-quiz / next.
13. `.gitignore` excludes the state dir + `workspace/` + `vendor/` + `docs/`.
