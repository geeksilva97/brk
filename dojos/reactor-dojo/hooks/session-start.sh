#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject a short
# tutoring directive into the agent's context. State is PER-PROJECT (lives in the
# project's .reactor-dojo/ dir) so progress is scoped to the folder you're in — a new
# folder starts fresh at Step 1 instead of inheriting another project's progress.
#
# Output contract: a single JSON object on stdout with hookSpecificOutput.
# We keep additionalContext on ONE line with NO double quotes so we can emit it
# without a JSON library. The agent reads the full step file itself (it has Read).
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.reactor-dojo"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"

mkdir -p "$DATA_DIR" 2>/dev/null || true

# Bootstrap progress on first run.
if [[ ! -f "$PROGRESS" ]]; then
  printf '%s\n' '{ "step": 1, "completed": [], "spine_file": "workspace/blocking_echo.rb", "mode": "local-jailed" }' > "$PROGRESS"
fi

raw="$(cat "$PROGRESS" 2>/dev/null || echo '{}')"

step="$(printf '%s' "$raw" | grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)"
step="${step:-1}"
spine="$(printf '%s' "$raw" | sed -n 's/.*"spine_file"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
spine="${spine:-workspace/blocking_echo.rb}"
mode="$(printf '%s' "$raw" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
mode="${mode:-local-jailed}"

stepfile="$(printf '%s/curriculum/step-%02d.md' "$ROOT" "$step")"

warn=""
[[ -d "$PWD/docs" ]] || warn="${warn}Offline docs bundle missing in this project so run /reactor-dojo:setup first. "

ctx="reactor-dojo is active and the learner is on Step ${step}. The topic is a reactor-based server in Ruby. Read the curriculum file at ${stepfile} and run the tutor skill to drive it. You are the TUTOR, not the author: open with the Frame, use the AskUserQuestion tool at the diagnose, design, and reflect checkpoints (the wrong-answer options are the known misconceptions in the step file), then have the LEARNER type the spine file (${spine}) themselves. Do NOT write or edit that spine file; you may generate the glue/scaffold files named in the step and review the learner code by pointing at lines. Backend mode is ${mode}. Plugin root is ${ROOT} and the state dir is ${DATA_DIR}; the state helper is ${ROOT}/bin/dojo.sh (use it for get/advance/status). ${warn}If the curriculum file is missing, tell the learner to run /reactor-dojo:setup."

step_name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv" 2>/dev/null)"
if [[ -n "$step_name" ]]; then
  title="reactor-dojo - Step ${step}: ${step_name}"
else
  title="reactor-dojo - Step ${step}"
fi
# Seed the title cache so the per-prompt title hook stays a no-op until /next changes the step.
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"
