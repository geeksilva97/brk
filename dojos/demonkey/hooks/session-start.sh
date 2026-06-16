#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject a short
# tutoring directive into the agent's context. State is PER-PROJECT (lives in the
# project's .demonkey/ dir) so progress is scoped to the folder you're in — a
# new folder starts fresh at Step 1 instead of inheriting another project's progress.
#
# Output contract: a single JSON object on stdout with hookSpecificOutput.
# We keep additionalContext on ONE line with NO double quotes so we can emit it
# without a JSON library. The agent reads the full step file itself (it has Read).
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.demonkey"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"

mkdir -p "$DATA_DIR" 2>/dev/null || true

# Bootstrap progress on first run.
if [[ ! -f "$PROGRESS" ]]; then
  printf '%s\n' '{ "step": 1, "completed": [], "spine_file": "workspace/echo.rb", "mode": "local-jailed" }' > "$PROGRESS"
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
command -v ruby >/dev/null 2>&1 || warn="${warn}Ruby not found on PATH so the servers cannot run until installed. "

# Has setup run in this project? (sentinel written by /demonkey:setup, or its artifacts.)
# If not, direct the agent to run setup as its FIRST action — so opening Claude in a fresh
# project sets itself up automatically, instead of the learner needing to know about /setup.
setup_done=0
[[ -f "$DATA_DIR/.setup_done" ]] && setup_done=1
[[ -d "$PWD/vendor/bundle" && -f "$PWD/docs/INDEX.md" ]] && setup_done=1
setup_prefix=""
if [[ "$setup_done" -eq 0 ]]; then
  setup_prefix="FIRST ACTION, before ANY tutoring: this project is not set up yet. Run the /demonkey:setup steps NOW — create workspace/, copy the pinned Gemfile + config.ru and vendor the gems (bundle install), build the offline docs bundle, and if Docker is present build the bench image. It is safe and idempotent and must run now while the network is available (before any offline jailing). Do it as your very first action, tell the learner what you set up, THEN continue with the tutoring directive that follows. === "
fi

ctx="${setup_prefix}demonkey is active and the learner is on Step ${step}. Read the curriculum file at ${stepfile} and run the tutor skill to drive it. You are the TUTOR, not the author. The order is teach-and-build FIRST, quiz to consolidate LAST: open with the Frame, then TEACH the mechanisms this step needs and point at the docs (naming how they will validate it, e.g. nc), have the LEARNER type the spine file (${spine}) themselves, review their code and verify locally, and ONLY THEN use the AskUserQuestion tool at the consolidation checkpoints (the step's diagnose/design/reflect questions, asked retrospectively about what they just built and saw; the wrong-answer options are the known misconceptions in the step file). Never quiz a primitive before the learner has implemented it. Do NOT write or edit that spine file; you may generate the glue files named in the step and review the learner code by pointing at lines. This dojo covers the PROCESS family ONLY (sockets, Rack, fork, preforking, master/signals, unicorn-like USR2) — threads, fibers, and ractors are explicitly out of scope; if the learner asks for them, say they are a separate course and keep to the path. Verification is LOCAL and lightweight: nc clients, curl for HTTP, ps/lsof for zombies and fd leaks, kill -SIGNAL to exercise the signal protocol, and a USR2 restart with a connected client to prove zero downtime. There is NO Docker/cgroup benchmark. These shell tools (nc, curl, ps STAT column, lsof, kill -SIGNAL) are NEW to a Ruby-only learner: the FIRST time a step uses one, introduce it before running it (what it is for, the exact command, how to read its output), then run it together. Never paste an unexplained ps/lsof/kill incantation as if they already know it. Backend mode is ${mode}. Plugin root is ${ROOT} and the state dir is ${DATA_DIR}; the state helper is ${ROOT}/bin/dojo.sh (use it for get/advance/status). ${warn}If the curriculum file or docs bundle are missing, run /demonkey:setup."

step_name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv" 2>/dev/null)"
if [[ -n "$step_name" ]]; then
  title="demonkey - Step ${step}: ${step_name}"
else
  title="demonkey - Step ${step}"
fi
# Seed the title cache so the per-prompt title hook stays a no-op until /next changes the step.
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"
