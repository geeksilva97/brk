#!/usr/bin/env bash
# UserPromptSubmit hook: keep the session title in sync with the current step.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.loopcraft"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"
CACHE="$DATA_DIR/.titled_step"

[[ -f "$PROGRESS" ]] || exit 0   # not a dojo project / not started

step="$(grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' "$PROGRESS" | grep -o '[0-9]*' | head -1)"
[[ -n "$step" ]] || exit 0

# Only act on change.
[[ "$step" == "$(cat "$CACHE" 2>/dev/null || true)" ]] && exit 0

name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv")"
label="loopcraft - Step ${step}${name:+: $name}"
printf '%s' "$step" > "$CACHE" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$label"
