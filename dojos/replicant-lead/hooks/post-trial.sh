#!/usr/bin/env bash
# PostToolUse hook (Bash): capture trial results and put them next to the learner's expected results.
#
# bin/trial.sh emits its result as a single marker line:
#   TRIAL_RESULT,step=<n>,<key>=<value>,...
# We append it to <project>/.replicant-lead/results.csv and hand the agent the ADR's Expected results
# side by side with the measured line, so beat 7 starts from the comparison. No-op otherwise.
#
# additionalContext is kept on ONE line with NO double quotes so it can be emitted without a JSON lib.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.replicant-lead"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
RESULTS="$DATA_DIR/results.csv"

PAYLOAD="$(cat 2>/dev/null || true)"
row="$(printf '%s' "$PAYLOAD" | grep -oE 'TRIAL_RESULT,step=[0-9]+(,[A-Za-z0-9_]+=[A-Za-z0-9_./:@-]*)*' | tail -1 || true)"
[[ -z "$row" ]] && exit 0

mkdir -p "$DATA_DIR" 2>/dev/null || true
[[ -f "$RESULTS" ]] || printf '%s\n' "recorded_at,result" > "$RESULTS"
printf '%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${row#TRIAL_RESULT,}" >> "$RESULTS"

spine="$("$ROOT/bin/dojo.sh" spine 2>/dev/null || true)"
expected="$(awk '/^##[[:space:]]+Expected results/{on=1; next} /^##[[:space:]]/{on=0} on && /^[[:space:]]*([-*]|[0-9]+[.)])[[:space:]]/' \
  "$PROJECT/$spine" 2>/dev/null | sed -E 's/^[[:space:]]*([-*]|[0-9]+[.)])[[:space:]]+//' | tr '"\\' "' " | paste -sd ';' - | sed 's/;/ ; /g')"

ctx="Trial recorded in ${RESULTS}. MEASURED: ${row#TRIAL_RESULT,}. LEARNER EXPECTED (from ${spine}): ${expected:-none found}. Beat 7: put these side by side for the learner, item by item. Do not explain any gap yet — ask the learner to explain the biggest one first."

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$ctx"
