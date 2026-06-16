#!/usr/bin/env bash
# UserPromptSubmit hook: keep the session title in sync with the current step.
#
# Claude Code only lets SessionStart and UserPromptSubmit set the title — there is
# no "/next was called" hook that can rename (PostToolUse can see the advance but
# cannot set sessionTitle). So this must be registered per-prompt. To avoid renaming
# on every prompt, it only EMITS when the step changed since we last set the title
# (cached in .titled_step): a trivial read-and-exit otherwise, a rename exactly at
# the /next boundary.
#
# No-op (exit 0, no output) outside a dojo project, so it never touches other sessions.
set -uo pipefail

DATA_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.reactor-dojo"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROGRESS="$DATA_DIR/progress.json"
CACHE="$DATA_DIR/.titled_step"

[[ -f "$PROGRESS" ]] || exit 0   # not a dojo project / not started

step="$(grep -o '"step"[[:space:]]*:[[:space:]]*[0-9]*' "$PROGRESS" | grep -o '[0-9]*' | head -1)"
[[ -n "$step" ]] || exit 0

# Only act on change — the title updates at the /next boundary, not every prompt.
[[ "$step" == "$(cat "$CACHE" 2>/dev/null || true)" ]] && exit 0

name="$(awk -F '\t' -v s="$step" '$1==s{print $2}' "$ROOT/curriculum/steps.tsv")"
label="reactor-dojo - Step ${step}${name:+: $name}"
printf '%s' "$step" > "$CACHE" 2>/dev/null || true

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$label"
