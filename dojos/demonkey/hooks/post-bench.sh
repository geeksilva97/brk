#!/usr/bin/env bash
# PostToolUse hook (Bash): capture memory-benchmark results into the persistent
# results table.
#
# env/bench/run.sh emits its result as a single marker line:
#   PDOJO_RESULT,<server>,<budget>,<held>,<peak_rss_mb>,<oom>
# We grep the tool payload for that marker (robust through JSON escaping because the
# fields are comma-separated bare tokens) and append to results.csv. No-op otherwise.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.demonkey"   # per-project, matches dojo.sh/session-start
RESULTS="$DATA_DIR/results.csv"
HEADER="server,mem_budget,held,peak_rss_mb,oom_killed"

PAYLOAD="$(cat 2>/dev/null || true)"
rows="$(printf '%s' "$PAYLOAD" | grep -oE 'PDOJO_RESULT,[A-Za-z0-9_./:+-]*(,[A-Za-z0-9_./:+ -]*)*' || true)"
[[ -z "$rows" ]] && exit 0

mkdir -p "$DATA_DIR" 2>/dev/null || true
[[ -f "$RESULTS" ]] || printf '%s\n' "$HEADER" > "$RESULTS"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  printf '%s\n' "${line#PDOJO_RESULT,}" >> "$RESULTS"
done <<< "$rows"

exit 0
