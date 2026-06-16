#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject a short
# tutoring directive into the agent's context. State is PER-PROJECT (lives in the
# project's .loopcraft/ dir) so progress is scoped to the folder you're in.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.loopcraft"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"

mkdir -p "$DATA_DIR" 2>/dev/null || true

# Bootstrap progress on first run.
if [[ ! -f "$PROGRESS" ]]; then
  printf '%s\n' '{ "step": 1, "completed": [], "spine_file": "workspace/agent.ts", "mode": "local-jailed" }' > "$PROGRESS"
fi

raw="$(cat "$PROGRESS" 2>/dev/null || echo '{}')"

step="$(printf '%s' "$raw" | grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)"
step="${step:-1}"
spine="$(printf '%s' "$raw" | sed -n 's/.*"spine_file"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
spine="${spine:-workspace/agent.ts}"
mode="$(printf '%s' "$raw" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
mode="${mode:-local-jailed}"

stepfile="$(printf '%s/curriculum/step-%02d.md' "$ROOT" "$step")"

warn=""
command -v node >/dev/null 2>&1 || warn="${warn}Node.js not found on PATH so the agent cannot run until installed. "
command -v ollama >/dev/null 2>&1 || warn="${warn}Ollama not found on PATH. Install it from https://ollama.ai. "

# Has setup run in this project?
setup_done=0
[[ -f "$DATA_DIR/.setup_done" ]] && setup_done=1
[[ -d "$PWD/workspace" ]] && setup_done=1
setup_prefix=""
if [[ "$setup_done" -eq 0 ]]; then
  setup_prefix="FIRST ACTION, before ANY tutoring: this project is not set up yet. Run the /loopcraft:setup steps NOW — create workspace/ and build the initial Modelfile. No npm install needed (Node 22+ runs .ts natively). It is safe and idempotent and must run now. Do it as your very first action, tell the learner what you set up, THEN continue with the tutoring directive that follows. === "
fi

ctx="${setup_prefix}loopcraft is active and the learner is on Step ${step}. Read the curriculum file at ${stepfile} and run the tutor skill to drive it. You are the TUTOR, not the author. The order is teach-and-build FIRST, quiz to consolidate LAST: open with the Frame, then TEACH the mechanisms this step needs and point at the docs, have the LEARNER type the spine file (${spine}) themselves, review their code and verify locally, and ONLY THEN use the AskUserQuestion tool at the consolidation checkpoints. Never quiz a primitive before the learner has implemented it. Do NOT write or edit that spine file; you may generate glue files. This dojo covers building an AI agent loop with tool calling in TypeScript — from a raw LLM call to a full agent with weather, search, and skills. Verification is LOCAL: run the agent with `node workspace/agent.ts`, check outputs, ask questions. The model can be any Ollama model (qwen3:8b is suggested but not required). Backend mode is ${mode}. Plugin root is ${ROOT} and the state dir is ${DATA_DIR}; the state helper is ${ROOT}/bin/dojo.sh. ${warn}If the curriculum file is missing, run /loopcraft:setup."

step_name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv" 2>/dev/null)"
if [[ -n "$step_name" ]]; then
  title="loopcraft - Step ${step}: ${step_name}"
else
  title="loopcraft - Step ${step}"
fi
# Seed the title cache.
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"
