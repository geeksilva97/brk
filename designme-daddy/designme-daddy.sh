#!/usr/bin/env bash
# Launch Claude Code for the designme-daddy dojo, IN YOUR OWN PROJECT DIR:
#   - loads the designme-daddy plugin (the tutor, hooks, commands),
#   - disallows web access (WebSearch + WebFetch) at the CLI, so the interview is
#     offline by design — belt-and-suspenders with the plugin's own guard hook.
#
# This is a NO-CODE dojo: you talk through the design of a ride-sharing service
# (Uber/Lyft) across 8 interview phases, and the tutor plays the interviewer —
# it scores your reasoning and only advances when you've earned it. There is no
# code to write and nothing to install; the dojo's only artifact is a per-project
# .designme-daddy/ state dir plus a docs/ bundle of cheatsheets you may consult.
#
# Usage:
#   designme-daddy.sh [project-dir] [claude args...]
#
#   designme-daddy.sh                       # run the dojo in the CURRENT dir
#   designme-daddy.sh /tmp/my-interview     # create/enter that dir and run there
#   designme-daddy.sh /tmp/ws --model qwen2.5-coder:32b   # ...with a local model
#   designme-daddy.sh --model qwen2.5-coder:32b           # current dir + a model
#
# Tip: symlink this onto your PATH (e.g. ln -s "$PWD/designme-daddy.sh" ~/bin/designme-daddy)
# so you can run `designme-daddy /tmp/ws` from anywhere.
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
# meant to think and reason through the design themselves; a grayed-out "type this"
# hand-out breaks that. The flag is read from the process env at startup, so it must
# be set HERE, before claude launches — a plugin's settings.json only supports the
# `agent`/`subagentStatusLine` keys (not `env`), and a hook runs too late to set it.
export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false

echo "designme-daddy → project: $(pwd)   plugin: $PLUGIN_DIR   (web disabled, prompt-suggestions off)" >&2

exec claude \
  --plugin-dir "$PLUGIN_DIR" \
  "$@" \
  --disallowed-tools WebSearch WebFetch
