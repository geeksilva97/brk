---
name: forge
description: Scaffold a complete, loadable tutored coding-dojo plugin for any topic — either by interviewing an instructor or by self-servicing from a topic string using web research. Copies the generic dojo templates, substitutes placeholders, and generates a topic-tailored curriculum. Use when the instructor runs /dojo-forge:new or asks to create/generate a new dojo plugin for a subject.
---

# dojo-forge — the dojo generator

You generate **tutored coding-dojo plugins** — Claude Code plugins shaped exactly like the reference
`c10k-dojo`: a Socratic tutor that quizzes the learner, makes them type the load-bearing "spine" code
themselves, and enforces an offline jail through hooks. Most of a dojo is topic-agnostic and lives as
templates in `${CLAUDE_PLUGIN_ROOT}/templates/`. Your job is to produce a complete, validated plugin
directory — either from an interview or from self-directed research.

You run in one of two modes, selected by whether the instructor provides details interactively or
just gives a topic:

- **INTERVIEW mode** — the instructor answers questions via `AskUserQuestion`. Use this when the
  instructor knows the domain and wants control over the spine progression.
- **SELF-SERVICE mode** — the instructor provides only a topic (e.g. `"Rust parsers"` or
  `"a key-value store in Go"`). You research the topic with `WebSearch`, synthesize the spine
  progression yourself, and scaffold the plugin without further questions. Use this when the
  instructor wants to learn the topic and doesn't already have a curriculum in mind.

Both modes converge on the same **SCAFFOLD** phase.

---

## Mode selection

If the `/dojo-forge:new` command carries arguments (a topic string), run in **SELF-SERVICE** mode.
If the command carries no arguments, run in **INTERVIEW** mode.

In SELF-SERVICE mode, you may use `WebSearch` to research the topic during the RESEARCH phase only.
The generated plugin's jail hook will block `WebFetch`/`WebSearch` for the learner — that constraint
remains untouched.

---

## Phase 1a — RESEARCH (SELF-SERVICE mode only)

When the instructor provides a topic and no further details, you must build the curriculum from
scratch. Use `WebSearch` to:

1. **Understand the topic's learning path.** Search for tutorials, canonical references, and
   "how to learn X" guides. Identify the standard progression a beginner follows — what comes
   first, what builds on it, what the milestones are.

2. **Find the canonical references.** Search for the official docs, man pages, or reference
   material the learner should read. Note what can be bundled offline (man pages, ri docs, static
   HTML dumps) vs. what must be referenced by URL.

3. **Identify the common pitfalls.** Search for "X gotchas", "X mistakes", "X for beginners" to
   find the misconceptions and bugs that trip up newcomers. These become your quiz distractors and
   gotchas sections.

4. **Determine the natural spine progression (4–12 steps).** Each step must:
   - Build on the previous step's working code.
   - Introduce exactly one new concept.
   - Have a runnable success check (a command the learner can run to verify their code works).
   - Be small enough to complete in one sitting.

5. **Identify the "given black boxes."** What does the learner NOT need to derive from scratch?
   (e.g., a protocol parser, a test harness, a boilerplate skeleton.) These become cheatsheets.

After research, compute all the same values the interview would have produced:

- **Topic** — the human-readable subject (e.g. "a parser combinators library in Rust").
- **Language / runtime** — inferred from the topic or defaulted (Ruby if ambiguous).
- **Plugin name** — kebab-case `<topic-slug>-dojo`.
- **Spine progression** — 4–12 milestones, each with: concept, spine file, success check.
- **Constraint / jail** — offline by default; identify which docs to bundle.
- **Win-condition** — runnable check per step; decide if a benchmark is appropriate.
- **Given black boxes** — cheatsheets for things the learner shouldn't derive.

**Important:** after researching, present a **compact spec** to the instructor for confirmation
(plugin name, topic, language, the numbered ramp with spine files + checks, the jail, the
cheatsheets). Even in self-service mode, get a final "looks good, proceed" before scaffolding.
This is the only human gate in self-service mode — one confirmation, then full auto.

---

## Phase 1b — INTERVIEW (when no topic is provided)

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
| `{{PLUGIN_NAME}}` | kebab name, e.g. `reactor-dojo`, `loopcraft` |
| `{{STATE_DIR}}` | `.<plugin-name>`, e.g. `.reactor-dojo`, `.loopcraft` |
| `{{TOPIC}}` | human topic, e.g. `a reactor-based server`, `an AI agent loop with tool calling` |
| `{{TOPIC_DESCRIPTION}}` | one-sentence manifest description (mention Socratic tutor + type-the-spine + jail) |
| `{{LANGUAGE}}` | e.g. `Ruby`, `TypeScript` |
| `{{RUNTIME_CMD}}` | e.g. `ruby`, `npx tsx` |
| `{{AUTHOR}}` | instructor name (ask or default to the repo's git user) |
| `{{KEYWORDS}}` | JSON array, e.g. `["ruby","reactor","event-loop","workshop","tutor"]` |
| `{{FIRST_SPINE}}` | **step 1's spine file** (must match `steps.tsv` row 1's spine col), e.g. `workspace/blocking_echo.rb`, `workspace/agent.ts` |
| `{{DEPS_HINT}}` | one sentence naming the pinned deps, e.g. `The set is stdlib-only.`, `ollama-ai-provider + tsx + @types/node.` |
| `{{SETUP_CHECK_CMDS}}` | shell commands that check runtime tooling (one per line, each appends to `warn`), e.g. `command -v node >/dev/null 2>&1 || warn="${warn}Node.js not found. "` |
| `{{SETUP_DONE_SENTINEL}}` | extra sentinel checks beyond `.setup_done`, e.g. `[ -d "$PWD/workspace" ] && setup_done=1` |
| `{{SETUP_SUMMARY}}` | one-line summary for SessionStart prefix, e.g. `create workspace/, vendor the gems, build the offline docs` |
| `{{SETUP_TOOLING}}` | verification commands for `/setup`, e.g. `ruby --version`, `ollama --version` |
| `{{TUTOR_SCOPE}}` | one-sentence scope description for SessionStart, e.g. `This dojo covers the PROCESS family ONLY — threads, fibers, and ractors are explicitly out of scope.` |
| `{{VERIFICATION_METHOD}}` | how steps are verified, e.g. `nc clients, curl for HTTP, ps/lsof`, `npx tsx, check outputs, ask questions` |

### 2b. Copy the generic skeleton verbatim, substituting placeholders
From `${CLAUDE_PLUGIN_ROOT}/templates/`, copy into `./<PLUGIN_NAME>/`:
- `.claude-plugin/plugin.json`
- `skills/tutor/SKILL.md`
- `hooks/hooks.json`, `hooks/session-start.sh`, `hooks/title.sh`, `hooks/guard.sh`
- `bin/dojo.sh`
- `commands/start.md`, `next.md`, `status.md`, `hint.md`, `reveal.md`, `setup.md`
- `env/docs/build-bundle.sh`
- `gitignore.tmpl` → write as `./<PLUGIN_NAME>/.gitignore`
- `launch.sh.tmpl` → write as `./<PLUGIN_NAME>/<PLUGIN_NAME>.sh` (the root launcher script)

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
`chmod +x` the five scripts: `hooks/session-start.sh`, `hooks/title.sh`, `hooks/guard.sh`,
`bin/dojo.sh`, `env/docs/build-bundle.sh`, `<PLUGIN_NAME>.sh`.

### 2d. Generate the curriculum
Create `./<PLUGIN_NAME>/curriculum/`:

- **`steps.tsv`** — one TAB-separated row per milestone, NO header:
  `<step_num>\t<title>\t<spine_file>\t<kind>`
  Use `-` as the spine for steps with no learner-typed file (pure-concept/measurement steps); the
  state helper maps `-` to `workspace/`. `kind` is a short tag you choose (e.g. `concept`, `build`,
  `check`). Make sure columns are real tab characters, not spaces.

- **`step-NN.md`** (zero-padded) — one per milestone, following the format in
  `${CLAUDE_PLUGIN_ROOT}/templates/curriculum/step-template.md`. Fill EVERY section with real,
  topic-specific content derived from the interview or research:
  - **Frame** (1–3 sentences: the problem + why the previous step is inadequate),
  - **Teach the mechanisms**: explain each NEW concept with a one-line "what and why" or a leading
    question, point at the exact doc in the bundle, and name how the learner will verify it,
  - **GIVEN black box** note IF this step relies on a cheatsheet (else drop the section),
  - **Spine**: exactly what the learner types, the goal, the shape, and `Read first:` docs,
  - **Agent role**: `[explain]` / `[glue]` / `[scaffold]` / `[review]` lines (drop any that don't
    apply, but keep at least `[explain]` and `[review]`),
  - **Gotchas**: the classic bugs and misconceptions — about THIS step only; never "Step N+1 adds…",
  - **Success check**: concrete runnable command(s) + expected output (the win-condition),
  - **Consolidate**: quiz **topics and angles**, NOT verbatim questions. Provide 2–3 angles:
    *Diagnose* (what breaks and why), *Design* (why is the API shaped this way), *Reflect* (what's
    the insight). The tutor composes actual questions at runtime based on what the learner built
    and where they struggled, drawing distractors from the gotchas. Write angles like:
    "Why does X happen when Y?" or "What's the one insight that makes Z click?"
    — NOT "Which of the following is correct about X? A) ... B) ..."
    Angles must target the learner's OWN spine and concepts — never provided scaffold/glue — and
    must not depend on a later step's mechanism (invariants 14–15).
  - **Next step**: name the single next step; never offer a branch.

  The LAST step's "Next step" should congratulate and point at `/{{PLUGIN_NAME}}:status` instead of a
  next step. Do NOT leave any `{{...}}` placeholders in generated step files — they're authored, not
  templated.

- **`curriculum/reference/`** (optional) — if you wrote any reference implementations or starter
  stubs, put them here and point each step's front-matter `reference:` at them. Otherwise set
  `reference:` to `-` and the `/reveal` command degrades gracefully.

### 2e. Ship the cheatsheets (the GIVEN black boxes)
For each black box from the interview or research, write a **complete, committed** cheatsheet to
`./<PLUGIN_NAME>/env/docs/<thing>-cheatsheet.md`. It must be a real worked example the learner can
copy the *shape* of — this is GIVEN scaffolding, framed in the relevant step as provided, not derived.
`build-bundle.sh` copies every `*-cheatsheet.md` next to it into the learner's `docs/` automatically.

### 2f. README
Write `./<PLUGIN_NAME>/README.md` from the c10k-dojo README's shape: what it teaches, install
(`claude --plugin-dir ./<PLUGIN_NAME>`, or `./<PLUGIN_NAME>.sh [project-dir]` for the one-shot
launcher that also disables web + prompt suggestions), the `/setup` then `/start` flow, the
command list, how it's wired (hooks = jail, per-project state in `<STATE_DIR>/`), and the layout
tree (include `<PLUGIN_NAME>.sh` — the root launcher).

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
0. **Root launcher script.** The plugin ships `<PLUGIN_NAME>.sh` at its root — a one-shot
   `exec claude --plugin-dir … --disallowed-tools WebSearch WebFetch` wrapper that the learner
   runs from any project dir. It resolves its own plugin dir before cd-ing, exports
   `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false` (must be set before claude launches — a hook is
   too late), and prints a one-line status. This is the documented entrypoint in the README; the
   bare `claude --plugin-dir` path still works but doesn't disable prompt suggestions or web tools
   at the CLI level.
1. The manifest has **no `"hooks"` field** — `hooks/hooks.json` auto-loads; referencing it causes a
   "Duplicate hooks file" error.
2. State is **per-project** in `${CLAUDE_PROJECT_DIR:-$PWD}/<STATE_DIR>/progress.json` — never global.
3. Title sync: `SessionStart` seeds the title + cache; `UserPromptSubmit` re-titles **only when the
   step changed**; no-op outside the project. Only those two events set the title.
4. All consolidation questions are **free-text** — the tutor asks open-ended questions, the learner
   types their understanding in their own words, and the tutor scores 1–5 based on whether the answer
   covers the key concepts. If the score is below 3, the tutor re-explains and asks again — as many times as needed. Nonsense, vague, or 'I don't know' answers do NOT count; no advancement without understanding.
   The step file provides the **core question and what a good answer covers**, not multiple-choice options.
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
12. The `step-NN.md` format: frame / teach-mechanisms / GIVEN (optional) / spine / agent-role /
    gotchas / success-check / consolidate (dynamic quiz topics, NOT fixed questions) / next.
    Quizzes are **dynamic**: the step file provides quiz **topics and angles** (what to quiz about),
    not verbatim questions. The tutor composes each quiz at runtime based on what the learner
    actually built, where they struggled, and what they observed.
13. `.gitignore` excludes the state dir + `workspace/` + `vendor/` + `docs/`.
14. **No forward references.** Each step stands alone — the tutor never previews, teases, or
    explains a later step's mechanism, and generated step files don't foreshadow ("this pays off in
    Step N+1") in their Frame, Gotchas, or Consolidate angles. The only forward reference allowed is
    the bare "Next:" line naming the next step's title.
15. **Never quiz the learner on code they didn't write.** Review comments and consolidation
    questions target ONLY the learner's spine. Every `[scaffold]`/`[glue]`/GIVEN file and provided
    helper is a black box: the tutor may state what it does, never ask the learner to explain or
    justify it.