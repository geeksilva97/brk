#!/usr/bin/env bash
# PostToolUse hook (Bash): capture benchmark results into the persistent results table.
#
# run.sh emits its result as a single marker line:
#   C10K_RESULT,<server>,<model>,<budget>,<max_conns>,<fail_reason>,<req_s>,<p50>,<p99>,<rss_mb>,<oom>
# We grep the tool payload for that marker (robust through JSON escaping because the
# fields are comma-separated bare tokens) and append to results.csv. No-op otherwise.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.c10k-dojo"   # per-project, matches dojo.sh/session-start
RESULTS="$DATA_DIR/results.csv"
HEADER="server,model,budget,max_conns,fail_reason,req_s,p50_ms,p99_ms,peak_rss_mb,oom_killed"

PAYLOAD="$(cat 2>/dev/null || true)"
rows="$(printf '%s' "$PAYLOAD" | grep -oE 'C10K_RESULT,[A-Za-z0-9_./:+-]*(,[A-Za-z0-9_./:+ -]*)*' || true)"
[[ -z "$rows" ]] && exit 0

mkdir -p "$DATA_DIR" 2>/dev/null || true
[[ -f "$RESULTS" ]] || printf '%s\n' "$HEADER" > "$RESULTS"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  printf '%s\n' "${line#C10K_RESULT,}" >> "$RESULTS"
done <<< "$rows"

exit 0
