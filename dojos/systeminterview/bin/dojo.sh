#!/usr/bin/env bash
# systeminterview state helper. Reads/writes progress.json in the PROJECT's
# .systeminterview/ dir and the step table in curriculum/steps.tsv.
# No jq dependency — flat-JSON parsing.
#
# This is a conversation-first dojo — no spine files, no workspace.
# Step tracking only.
#
# Usage:
#   dojo.sh get                 -> current step number
#   dojo.sh title [step]        -> step title
#   dojo.sh mode                -> backend mode
#   dojo.sh set-mode <mode>     -> set backend mode
#   dojo.sh advance             -> mark current step completed, move to next
#   dojo.sh status              -> print progress.json
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"
TSV="$ROOT/curriculum/steps.tsv"
mkdir -p "$DATA_DIR" 2>/dev/null || true

ensure() {
  [[ -f "$PROGRESS" ]] || printf '%s\n' \
    '{ "step": 1, "completed": [], "mode": "conversation" }' > "$PROGRESS"
}

read_field() { # read_field <key>
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" "$PROGRESS" | head -1
}

read_completed() {
  sed -n 's/.*"completed"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$PROGRESS" | head -1
}

tsv_col() { # tsv_col <step> <colnum>
  awk -F '\t' -v s="$1" -v c="$2" '$1==s{print $c}' "$TSV"
}

write_progress() { # step completed mode
  printf '{ "step": %s, "completed": [%s], "mode": "%s" }\n' \
    "$1" "$2" "$3" > "$PROGRESS"
}

ensure
cmd="${1:-}"; shift || true
case "$cmd" in
  get)    read_field step ;;
  mode)   read_field mode ;;
  title)  tsv_col "${1:-$(read_field step)}" 2 ;;
  status) cat "$PROGRESS" ;;
  set-mode)
    write_progress "$(read_field step)" "$(read_completed)" "${1:-conversation}" ;;
  advance)
    step="$(read_field step)"; comp="$(read_completed)"
    if [[ -z "$comp" ]]; then comp="$step"; else comp="$comp, $step"; fi
    next=$((step + 1))
    write_progress "$next" "$comp" "$(read_field mode)"
    echo "Advanced to step $next ($(tsv_col "$next" 2))" ;;
  *) echo "usage: dojo.sh {get|title|mode|set-mode <m>|advance|status} [step]" >&2; exit 2 ;;
esac