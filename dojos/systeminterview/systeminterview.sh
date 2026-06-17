#!/usr/bin/env bash
# Launch Claude Code for the systeminterview workshop, IN YOUR OWN PROJECT DIR:
#   - loads the systeminterview plugin (the tutor, hooks, commands),
#   - disallows web access (WebSearch + WebFetch) at the CLI, so the dojo is
#     offline by design — belt-and-suspenders with the plugin's own guard hook.
#
# The dojo runs in the project directory you pick (NOT the plugin's own dir) —
# your workspace/ and the per-project .systeminterview/ state land there. The
# SessionStart hook auto-runs setup on first launch, then drops you into Step 1.
#
# Usage:
#   systeminterview.sh [project-dir] [claude args...]
#
#   systeminterview.sh                       # run the dojo in the CURRENT dir
#   systeminterview.sh /tmp/my-workshop      # create/enter that dir and run there
#   systeminterview.sh /tmp/ws --model llama3:8b   # ...with a local model
#   systeminterview.sh --model llama3:8b           # current dir + a model
#
# Tip: symlink this onto your PATH (e.g. ln -s "$PWD/systeminterview.sh" ~/bin/systeminterview)
# so you can run `systeminterview /tmp/ws` from anywhere.
set -euo pipefail

# Resolve the plugin dir (where THIS script lives) to an absolute path BEFORE we
# cd, so it stays valid no matter which project dir we switch into.
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional first arg = the project dir to run the dojo in. If it doesn't start
# with '-', treat it as the dir (create it if needed); otherwise it's a claude arg
# and we stay in the current dir.
if [[ "${1:-}" != "" && "${1#-}" == "$1" ]]; then
  PROJECT_DIR="$1"; shift
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"
fi

# Turn OFF Claude Code's input-box prompt suggestions for the dojo. The learner is
# meant to think and type the load-bearing code themselves; a grayed-out "type this"
# hand-out breaks that. The flag is read from the process env at startup, so it must
# be set HERE, before claude launches — a plugin's settings.json only supports the
# `agent`/`subagentStatusLine` keys (not `env`), and a hook runs too late to set it.
export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false

echo "systeminterview → project: $(pwd)   plugin: $PLUGIN_DIR   (web disabled, prompt-suggestions off)" >&2

exec claude \
  --plugin-dir "$PLUGIN_DIR" \
  "$@" \
  --disallowed-tools WebSearch WebFetch