#!/usr/bin/env bash
# UserPromptSubmit hook: keep the session title in sync with the current step.
#
# Claude Code only lets SessionStart and UserPromptSubmit set the title, so this runs per prompt but
# only EMITS when the step changed since the title was last set (cached in .titled_step).
#
# No-op (exit 0, no output) outside a dojo project, so it never touches other sessions.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.replicant-lead"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"
CACHE="$DATA_DIR/.titled_step"

[[ -f "$PROGRESS" ]] || exit 0

step="$(grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' "$PROGRESS" | grep -o '[0-9]*' | head -1)"
[[ -n "$step" ]] || exit 0

[[ "$step" == "$(cat "$CACHE" 2>/dev/null || true)" ]] && exit 0

name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv")"
label="replicant-lead - Step ${step}${name:+: $name}"
printf '%s' "$step" > "$CACHE" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$label"
