#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject a short
# tutoring directive into the agent's context. State is PER-PROJECT (lives in the
# project's .c10k-dojo/ dir) so progress is scoped to the folder you're in — a new
# folder starts fresh at Step 1 instead of inheriting another project's progress.
#
# Output contract: a single JSON object on stdout with hookSpecificOutput.
# We keep additionalContext on ONE line with NO double quotes so we can emit it
# without a JSON library. The agent reads the full step file itself (it has Read).
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.c10k-dojo"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"

mkdir -p "$DATA_DIR" 2>/dev/null || true

# Bootstrap progress on first run.
if [[ ! -f "$PROGRESS" ]]; then
  printf '%s\n' '{ "step": 1, "completed": [], "spine_file": "workspace/echo.rb", "tier": "none", "mode": "local-jailed" }' > "$PROGRESS"
fi

raw="$(cat "$PROGRESS" 2>/dev/null || echo '{}')"

step="$(printf '%s' "$raw" | grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)"
step="${step:-1}"
spine="$(printf '%s' "$raw" | sed -n 's/.*"spine_file"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
spine="${spine:-workspace/echo.rb}"
mode="$(printf '%s' "$raw" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
mode="${mode:-local-jailed}"

stepfile="$(printf '%s/curriculum/step-%02d.md' "$ROOT" "$step")"

warn=""
command -v docker >/dev/null 2>&1 || warn="${warn}Docker not found so /c10k-dojo:bench is disabled until installed. "
[[ -d "$PWD/docs" ]] || warn="${warn}Offline docs bundle missing in this project so run /c10k-dojo:setup first. "

ctx="c10k-dojo is active and the learner is on Step ${step}. Read the curriculum file at ${stepfile} and run the tutor skill to drive it. You are the TUTOR, not the author: open with the Frame, use the AskUserQuestion tool at the diagnose, design, and reflect checkpoints (the wrong-answer options are the known misconceptions in the step file), then have the LEARNER type the spine file (${spine}) themselves. Do NOT write or edit that spine file; you may generate the glue files named in the step and review the learner code by pointing at lines. Backend mode is ${mode}. Plugin root is ${ROOT} and the state dir is ${DATA_DIR}; the state helper is ${ROOT}/bin/dojo.sh (use it for get/advance/status). ${warn}If the curriculum file is missing, tell the learner to run /c10k-dojo:setup."

step_name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv" 2>/dev/null)"
if [[ -n "$step_name" ]]; then
  title="c10k-dojo - Step ${step}: ${step_name}"
else
  title="c10k-dojo - Step ${step}"
fi
# Seed the title cache so the per-prompt title hook stays a no-op until /next changes the step.
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"
