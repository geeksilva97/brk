#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject the lead-mode directive.
# State is PER-PROJECT (<project>/.replicant-lead/), so a new folder starts fresh.
#
# Output contract: a single JSON object on stdout with hookSpecificOutput. additionalContext is kept
# on ONE line with NO double quotes so it can be emitted without a JSON library.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.replicant-lead"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"

mkdir -p "$DATA_DIR" 2>/dev/null || true

step="$("$ROOT/bin/dojo.sh" get)"
spine="$("$ROOT/bin/dojo.sh" spine)"
stepfile="$(printf '%s/curriculum/step-%02d.md' "$ROOT" "$step")"

warn=""
command -v ruby >/dev/null 2>&1 || warn="${warn}Ruby not found on PATH. "
command -v sqlite3 >/dev/null 2>&1 || warn="${warn}sqlite3 CLI not found. "

setup_prefix=""
if [[ ! -f "$DATA_DIR/.setup_done" ]]; then
  setup_prefix="FIRST ACTION, before ANY tutoring: this project is not set up yet. Run the /replicant-lead:setup steps NOW — vendor the sqlite3 gem, copy the GIVEN baseline system into workspace/, build the offline docs bundle. Tell the learner what you set up, THEN continue with the directive that follows. === "
fi

ctx="${setup_prefix}replicant-lead is active and the learner is on Step ${step}. This is LEAD MODE: the learner leads, you execute. Read the curriculum file at ${stepfile} and run the tutor skill to drive its eight beats. You write the ADR (${spine}) and all of workspace/ — but you RECORD decisions, you never make them: every row of the ADR Decision table must trace to something the learner said, with their words in the Learner said column; when a decision is missing, ask a plain question with no options, defaults, ranges, or recommendations, and count every such ask. Never propose expected-result numbers. Start with the incident and its live repro, let the learner direct a first-draft ADR BEFORE you teach anything, then teach against their draft. Hooks block workspace/ code until the ADR is complete with numbered Expected results, block the trial on the same condition, and block edits to the GIVEN harness and to the plugin. Do not foreshadow later steps. The trial is ${ROOT}/bin/trial.sh ${step}; the incident repro is ${ROOT}/bin/trial.sh ${step} --repro. Plugin root is ${ROOT}; the state helper is ${ROOT}/bin/dojo.sh (get/advance/status). ${warn}"

step_name="$("$ROOT/bin/dojo.sh" title)"
title="replicant-lead - Step ${step}${step_name:+: $step_name}"
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"
