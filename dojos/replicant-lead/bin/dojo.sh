#!/usr/bin/env bash
# replicant-lead state helper. Reads/writes progress.json in the PROJECT's .replicant-lead/ dir and
# the step table in curriculum/steps.tsv. No jq dependency — flat-JSON parsing.
#
# Lead mode can enter the ramp mid-way (the layers before it are a GIVEN baseline), so a new project
# starts at the FIRST row of steps.tsv, not at step 1.
#
# Usage:
#   dojo.sh get                 -> current step number
#   dojo.sh spine [step]        -> spine file (the step's ADR) for step (default: current)
#   dojo.sh title [step]        -> step title
#   dojo.sh kind  [step]        -> step kind (lead | build | ...)
#   dojo.sh advance             -> mark current step completed, move to the next row of steps.tsv
#   dojo.sh status              -> print progress.json
#   dojo.sh drill [on|off]      -> instructor toggle: plant the step's drill defect in the first build
#                                  (read by session-start; set it BEFORE the learner's session)
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.replicant-lead"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"
TSV="$ROOT/curriculum/steps.tsv"
mkdir -p "$DATA_DIR" 2>/dev/null || true

tsv_col() { # tsv_col <step> <colnum>
  awk -F '\t' -v s="$1" -v c="$2" '$1==s{print $c}' "$TSV"
}

write_progress() { # step completed spine
  printf '{ "step": %s, "completed": [%s], "spine_file": "%s", "mode": "subscription" }\n' \
    "$1" "$2" "$3" > "$PROGRESS"
}

ensure() {
  [[ -f "$PROGRESS" ]] && return
  local first
  first="$(awk -F '\t' 'NF{print $1; exit}' "$TSV")"
  write_progress "$first" "" "$(tsv_col "$first" 3)"
}

read_field() { # read_field <key>  (works for quoted or bare values)
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" "$PROGRESS" | head -1
}

read_completed() {
  sed -n 's/.*"completed"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$PROGRESS" | head -1
}

ensure
cmd="${1:-}"; shift || true
case "$cmd" in
  get)    read_field step ;;
  spine)  tsv_col "${1:-$(read_field step)}" 3 ;;
  title)  tsv_col "${1:-$(read_field step)}" 2 ;;
  kind)   tsv_col "${1:-$(read_field step)}" 4 ;;
  status) cat "$PROGRESS" ;;
  drill)
    case "${1:-}" in
      on)  touch "$DATA_DIR/.drill" ;;
      off) rm -f "$DATA_DIR/.drill" ;;
      "")  : ;;
      *)   echo "usage: dojo.sh drill [on|off]" >&2; exit 2 ;;
    esac
    [[ -f "$DATA_DIR/.drill" ]] && echo on || echo off ;;
  advance)
    step="$(read_field step)"; comp="$(read_completed)"
    if [[ -z "$comp" ]]; then comp="$step"; else comp="$comp, $step"; fi
    next="$(awk -F '\t' -v s="$step" 'found && NF{print $1; exit} $1==s{found=1}' "$TSV")"
    if [[ -z "$next" ]]; then
      write_progress "$step" "$comp" "$(tsv_col "$step" 3)"
      echo "Step $step was the last one in this course."
    else
      write_progress "$next" "$comp" "$(tsv_col "$next" 3)"
      echo "Advanced to step $next ($(tsv_col "$next" 2))"
    fi ;;
  *) echo "usage: dojo.sh {get|spine|title|kind|advance|status|drill [on|off]} [step]" >&2; exit 2 ;;
esac
