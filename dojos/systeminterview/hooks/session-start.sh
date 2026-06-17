#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject a
# conversation-first tutoring directive into the agent's context.
#
# This is a conversation dojo — no file writing, no workspace, no spine files.
# The learner discusses their design verbally; the tutor evaluates understanding
# through dialogue and advances steps when the learner demonstrates mastery.
#
# Output contract: a single JSON object on stdout with hookSpecificOutput.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"

mkdir -p "$DATA_DIR" 2>/dev/null || true

# Bootstrap progress on first run.
if [[ ! -f "$PROGRESS" ]]; then
  printf '%s\n' '{ "step": 1, "completed": [], "mode": "conversation" }' > "$PROGRESS"
fi

raw="$(cat "$PROGRESS" 2>/dev/null || echo '{}')"

step="$(printf '%s' "$raw" | grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)"
step="${step:-1}"
mode="$(printf '%s' "$raw" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
mode="${mode:-conversation}"

stepfile="$(printf '%s/curriculum/step-%02d.md' "$ROOT" "$step")"

ctx="systeminterview is active and the learner is on Step ${step}. The topic is designing scalable systems (system design interview format: Google Meet). Read the curriculum file at ${stepfile} and run the tutor skill to drive it. You are the TUTOR, playing the interviewer in a system design interview. This is a CONVERSATION-FIRST dojo: the learner discusses their design verbally — they do NOT write files. Your job is to evaluate their understanding through dialogue, ask probing questions, challenge their assumptions, and advance them when they demonstrate mastery. The order is teach-and-discuss FIRST, quiz to consolidate LAST: open with the Frame, TEACH the mechanisms this step needs (cite curriculum/reference/ for details), have the LEARNER explain their design choices verbally, probe and challenge their reasoning, and ONLY THEN ask consolidation questions. Never quiz before the learner has shown their thinking. This dojo covers system design interviews — architecture, scalability, estimation, trade-offs, communication. Backend mode is ${mode}. Plugin root is ${ROOT} and the state dir is ${DATA_DIR}; the state helper is ${ROOT}/bin/dojo.sh (use it for get/advance/status). If the curriculum file is missing, tell the learner to run /systeminterview:setup."

step_name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv" 2>/dev/null)"
if [[ -n "$step_name" ]]; then
  title="systeminterview - Step ${step}: ${step_name}"
else
  title="systeminterview - Step ${step}"
fi
# Seed the title cache so the per-prompt title hook stays a no-op until /next changes the step.
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"