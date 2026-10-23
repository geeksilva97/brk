#!/usr/bin/env bash
# Launch Claude Code for the replicant-lead workshop, IN YOUR OWN PROJECT DIR:
#   - loads the replicant-lead plugin (the tutor, hooks, commands),
#   - disallows web access (WebSearch + WebFetch) at the CLI — belt-and-suspenders with the guard,
#   - runs on your own Claude Code login and quota. Lead mode needs a frontier model to build a
#     real replicated system, so there is no local-model default here (unlike build-mode replicant).
#
# Usage:
#   replicant-lead.sh [project-dir] [claude args...]
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" != "" && "${1#-}" == "$1" ]]; then
  PROJECT_DIR="$1"; shift
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"
fi

# No grayed-out "type this" suggestions: the decisions are the learner's to word.
export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false

echo "replicant-lead → project: $(pwd)   plugin: $PLUGIN_DIR   (web disabled, prompt-suggestions off)" >&2

# --add-dir lets the tutor read its own curriculum and trials without a prompt each time; the guard
# still denies every write under the plugin dir.
exec claude \
  --plugin-dir "$PLUGIN_DIR" \
  --add-dir "$PLUGIN_DIR" \
  "$@" \
  --disallowed-tools WebSearch WebFetch
