#!/usr/bin/env bash
# SessionStart hook: resume the learner at their current step and inject a short
# tutoring directive into the agent's context. State is PER-PROJECT (lives in the
# project's .replicant/ dir) so progress is scoped to the folder you're in — a new
# folder starts fresh at Step 1 instead of inheriting another project's progress.
#
# Output contract: a single JSON object on stdout with hookSpecificOutput.
# We keep additionalContext on ONE line with NO double quotes so we can emit it
# without a JSON library. The agent reads the full step file itself (it has Read).
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.replicant"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"

mkdir -p "$DATA_DIR" 2>/dev/null || true

# Bootstrap progress on first run.
if [[ ! -f "$PROGRESS" ]]; then
  printf '%s\n' '{ "step": 1, "completed": [], "spine_file": "workspace/node.rb", "mode": "local-jailed" }' > "$PROGRESS"
fi

raw="$(cat "$PROGRESS" 2>/dev/null || echo '{}')"

step="$(printf '%s' "$raw" | grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)"
step="${step:-1}"
spine="$(printf '%s' "$raw" | sed -n 's/.*"spine_file"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
spine="${spine:-workspace/node.rb}"
mode="$(printf '%s' "$raw" | sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
mode="${mode:-local-jailed}"

stepfile="$(printf '%s/curriculum/step-%02d.md' "$ROOT" "$step")"

# Tooling checks — verify the runtime dependencies are available.
warn=""
command -v ruby >/dev/null 2>&1 || warn="${warn}Ruby not found on PATH. "
command -v sqlite3 >/dev/null 2>&1 || warn="${warn}sqlite3 CLI not found (used to inspect databases and checksum them). "

# Has setup run in this project? (sentinel written by /replicant:setup, or its artifacts.)
setup_done=0
[[ -f "$DATA_DIR/.setup_done" ]] && setup_done=1
[[ -f "$PWD/docs/INDEX.md" && -d "$PWD/workspace" ]] && setup_done=1
setup_prefix=""
if [[ "$setup_done" -eq 0 ]]; then
  setup_prefix="FIRST ACTION, before ANY tutoring: this project is not set up yet. Run the /replicant:setup steps NOW — create workspace/, vendor the sqlite3 gem, build the offline docs bundle. It is safe and idempotent and must run now while the network is available (before any offline jailing). Do it as your very first action, tell the learner what you set up, THEN continue with the tutoring directive that follows. === "
fi

ctx="${setup_prefix}replicant is active and the learner is on Step ${step}. The topic is distributed SQLite — building database replication from scratch in Ruby. Read the curriculum file at ${stepfile} and run the tutor skill to drive it. You are the TUTOR, not the author. The order is teach-and-build FIRST, quiz to consolidate LAST: open with the Frame, then TEACH the mechanisms this step needs and point at the docs, have the LEARNER type the spine file (${spine}) themselves, review their code and verify locally, and ONLY THEN use the AskUserQuestion tool at the consolidation checkpoints. Never quiz a primitive before the learner has implemented it. Do NOT write or edit that spine file; you may generate the glue/scaffold files named in the step and review the learner code by pointing at lines. This dojo covers REPLICATION ONLY — leader/follower, a hand-written write-ahead log, replication-lag consistency, crash recovery, and quorum/leader election. Sharding, multi-leader replication, and full Raft edge cases (log reconciliation, snapshotting) are explicitly OUT of scope; if asked, say they are a later phase and keep to the path. Verification is LOCAL and lightweight: run Ruby node processes, poke them with a small client or nc, inspect SQLite files with the sqlite3 CLI and a content checksum, and toggle the fault-injectable link to force failures on demand. Backend mode is ${mode}. Plugin root is ${ROOT} and the state dir is ${DATA_DIR}; the state helper is ${ROOT}/bin/dojo.sh (use it for get/advance/status). ${warn}If the curriculum file is missing, run /replicant:setup."

step_name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv" 2>/dev/null)"
if [[ -n "$step_name" ]]; then
  title="replicant - Step ${step}: ${step_name}"
else
  title="replicant - Step ${step}"
fi
# Seed the title cache so the per-prompt title hook stays a no-op until /next changes the step.
printf '%s' "$step" > "$DATA_DIR/.titled_step" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s","sessionTitle":"%s"}}\n' "$ctx" "$title"
