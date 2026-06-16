#!/bin/bash
# System Interview Dojo — State Management
# Usage: dojo.sh <command> [args]

DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROGRESS_FILE="$DIR/.systeminterview/progress.json"
STEPS_FILE="$DIR/curriculum/steps.tsv"

ensure_progress() {
  if [ ! -f "$PROGRESS_FILE" ]; then
    mkdir -p "$(dirname "$PROGRESS_FILE")"
    echo '{"step":1,"completed":[],"mode":"interview"}' > "$PROGRESS_FILE"
  fi
}

get_step() {
  ensure_progress
  cat "$PROGRESS_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['step'])"
}

get_spine() {
  local step="${1:-$(get_step)}"
  awk -F'\t' -v s="$step" '$1 == s {print $3}' "$STEPS_FILE"
}

get_title() {
  local step="${1:-$(get_step)}"
  awk -F'\t' -v s="$step" '$1 == s {print $2}' "$STEPS_FILE"
}

get_kind() {
  local step="${1:-$(get_step)}"
  awk -F'\t' -v s="$step" '$1 == s {print $4}' "$STEPS_FILE"
}

advance() {
  ensure_progress
  local current=$(get_step)
  local next=$((current + 1))
  local completed=$(cat "$PROGRESS_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['completed'])")
  python3 -c "
import sys, json
with open('$PROGRESS_FILE') as f:
    data = json.load(f)
data['completed'] = list(set(data['completed'] + [$current]))
data['step'] = $next
with open('$PROGRESS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
  echo "Advanced to step $next"
}

status() {
  ensure_progress
  local current=$(get_step)
  local total=$(wc -l < "$STEPS_FILE")
  echo "=== System Design Interview Dojo ==="
  echo "Current: Step $current / $total"
  echo "Title: $(get_title $current)"
  echo "Kind: $(get_kind $current)"
  echo "Spine: $(get_spine $current)"
  echo ""
  echo "Completed steps:"
  cat "$PROGRESS_FILE" | python3 -c "import sys,json; print(', '.join(map(str, json.load(sys.stdin)['completed'])))"
}

init() {
  mkdir -p "$(dirname "$PROGRESS_FILE")"
  echo '{"step":1,"completed":[],"mode":"interview"}' > "$PROGRESS_FILE"
  echo "Initialized. Starting at step 1."
}

case "${1:-status}" in
  get)      get_step ;;
  spine)    get_spine "${2:-}" ;;
  title)    get_title "${2:-}" ;;
  kind)     get_kind "${2:-}" ;;
  advance)  advance ;;
  status)   status ;;
  init)     init ;;
  *)        echo "Usage: dojo.sh {get|spine|title|kind|advance|status|init}" ;;
esac