#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject a short
# tutoring directive into the agent's context. State is PER-PROJECT (lives in the
# project's .designme-daddy/ dir) so progress is scoped to the folder you're in — a new
# folder starts fresh at Step 1 instead of inheriting another project's progress.
#
# Output contract: a single JSON object on stdout with hookSpecificOutput.
# We keep additionalContext on ONE line with NO double quotes so we can emit it
# without a JSON library. The agent reads the full step file itself (it has Read).
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.designme-daddy"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"

mkdir -p "$DATA_DIR" 2>/dev/null || true

# Bootstrap progress on first run.
if [[ ! -f "$PROGRESS" ]]; then
  printf '%s\n' '{ "step": 1, "completed": [], "spine_file": "-", "mode": "local-jailed" }' > "$PROGRESS"
fi

raw="$(cat "$PROGRESS" 2>/dev/null || echo '{}')"

step="$(printf '%s' "$raw" | grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)"
step="${step:-1}"
mode="$(printf '%s' "$raw" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
mode="${mode:-local-jailed}"

stepfile="$(printf '%s/curriculum/step-%02d.md' "$ROOT" "$step")"

# Tooling checks — a no-code dojo needs no runtime, so there is nothing to verify.
warn=""
: # no runtime or tooling to check — this dojo is pure system-design conversation

# Has setup run in this project? (sentinel written by /designme-daddy:setup, or its artifacts.)
setup_done=0
[[ -f "$DATA_DIR/.setup_done" ]] && setup_done=1
[[ -f "$PWD/docs/INDEX.md" ]] && setup_done=1
setup_prefix=""
if [[ "$setup_done" -eq 0 ]]; then
  setup_prefix="FIRST ACTION, before ANY tutoring: this project is not set up yet. Run the /designme-daddy:setup steps NOW — build the offline docs bundle of cheatsheets (there are no dependencies to install). It is safe and idempotent and must run now while the network is available (before any offline jailing). Do it as your very first action, tell the learner what you set up, THEN continue with the tutoring directive that follows. === "
fi

ctx="${setup_prefix}designme-daddy is active and the learner is on Step ${step}. The topic is a system-design interview for a ride-sharing service like Uber/Lyft. This is a NO-CODE dojo: there is NO code to write and no file to type. You are the INTERVIEWER and TUTOR, not the author of the design. Read the curriculum file at ${stepfile} and run the tutor skill to drive it. The order per step is: open with the Frame, TEACH the mechanisms and trade-offs this phase needs and point at the docs bundle, then make the LEARNER produce the design reasoning for this phase IN THEIR OWN WORDS — never hand them the answer. When they have reasoned it out, score it against the step's rubric and ask the consolidation questions (free-text, scored 1-5). Never quiz a concept before the learner has reasoned through it. Do NOT design FOR the learner: the load-bearing decisions (requirements, numbers, API shape, data model, architecture, the deep dive, the scaling plan, the trade-offs) are theirs to make; you ask leading questions and review. This dojo covers the SYSTEM-DESIGN INTERVIEW for a ride-sharing service ONLY — you design Uber/Lyft end to end across 8 phases. Low-level coding, language specifics, and unrelated systems are explicitly out of scope. Verification is conversational: there is no code to run — you score the learner's spoken/written reasoning against the step's rubric (is the decision justified, quantified where it should be, and does it name the trade-off?). Backend mode is ${mode}. Plugin root is ${ROOT} and the state dir is ${DATA_DIR}; the state helper is ${ROOT}/bin/dojo.sh (use it for get/advance/status). ${warn}If the curriculum file is missing, run /designme-daddy:setup."

step_name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv" 2>/dev/null)"
if [[ -n "$step_name" ]]; then
  title="designme-daddy - Step ${step}: ${step_name}"
else
  title="designme-daddy - Step ${step}"
fi
# Seed the title cache so the per-prompt title hook stays a no-op until /next changes the step.
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"
