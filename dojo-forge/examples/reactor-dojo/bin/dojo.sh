#!/usr/bin/env bash
# reactor-dojo state helper. Reads/writes progress.json in the PROJECT's .reactor-dojo/
# dir and the step table in curriculum/steps.tsv. No jq dependency — flat-JSON parsing.
#
# Usage:
#   dojo.sh get                 -> current step number
#   dojo.sh spine [step]        -> spine file path for step (default: current)
#   dojo.sh title [step]        -> step title
#   dojo.sh kind  [step]        -> step kind (e.g. concept|build|check)
#   dojo.sh mode                -> backend mode
#   dojo.sh set-mode <mode>     -> set backend mode (e.g. local-jailed | anthropic-api)
#   dojo.sh advance             -> mark current step completed, move to next
#   dojo.sh status              -> print progress.json
set -uo pipefail

# State is PER-PROJECT (lives in the learner's project dir), NOT global — so a new
# folder starts fresh at Step 1 instead of inheriting another project's progress.
DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.reactor-dojo"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"
TSV="$ROOT/curriculum/steps.tsv"
mkdir -p "$DATA_DIR" 2>/dev/null || true

ensure() {
  [[ -f "$PROGRESS" ]] || printf '%s\n' \
    '{ "step": 1, "completed": [], "spine_file": "workspace/blocking_echo.rb", "mode": "local-jailed" }' > "$PROGRESS"
}

read_field() { # read_field <key>  (works for quoted or bare values)
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" "$PROGRESS" | head -1
}

read_completed() {
  sed -n 's/.*"completed"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$PROGRESS" | head -1
}

tsv_col() { # tsv_col <step> <colnum>
  awk -F '\t' -v s="$1" -v c="$2" '$1==s{print $c}' "$TSV"
}

write_progress() { # step completed spine mode
  printf '{ "step": %s, "completed": [%s], "spine_file": "%s", "mode": "%s" }\n' \
    "$1" "$2" "$3" "$4" > "$PROGRESS"
}

ensure
cmd="${1:-}"; shift || true
case "$cmd" in
  get)    read_field step ;;
  mode)   read_field mode ;;
  spine)  tsv_col "${1:-$(read_field step)}" 3 ;;
  title)  tsv_col "${1:-$(read_field step)}" 2 ;;
  kind)   tsv_col "${1:-$(read_field step)}" 4 ;;
  status) cat "$PROGRESS" ;;
  set-mode)
    write_progress "$(read_field step)" "$(read_completed)" "$(read_field spine_file)" "${1:-local-jailed}" ;;
  advance)
    step="$(read_field step)"; comp="$(read_completed)"
    if [[ -z "$comp" ]]; then comp="$step"; else comp="$comp, $step"; fi
    next=$((step + 1))
    spine="$(tsv_col "$next" 3)"; [[ -z "$spine" || "$spine" == "-" ]] && spine="workspace/"
    write_progress "$next" "$comp" "$spine" "$(read_field mode)"
    echo "Advanced to step $next ($(tsv_col "$next" 2))" ;;
  *) echo "usage: dojo.sh {get|spine|title|kind|mode|set-mode <m>|advance|status} [step]" >&2; exit 2 ;;
esac
