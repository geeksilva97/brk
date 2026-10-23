#!/usr/bin/env bash
# Run the plugin-owned trial (or the incident repro) for a step against the learner's workspace.
#   trial.sh <step>           the graded trial — blocked by the guard until the ADR's expected
#                             results are filled in; prints one TRIAL_RESULT line
#   trial.sh <step> --repro   the step's incident, live (used in the Frame; never blocked)
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
WS="$PROJECT/workspace"

step="${1:-$("$ROOT/bin/dojo.sh" get)}"
kind="trial"; prefix="step"
[[ "${2:-}" == "--repro" ]] && { kind="repro"; prefix="repro"; }
script="$(printf '%s/env/trial/%s-%02d.rb' "$ROOT" "$prefix" "$step")"

[[ -f "$script" ]] || { echo "no ${kind} for step ${step} (${script})" >&2; exit 2; }
[[ -d "$WS/lib" ]] || { echo "workspace/ is not set up — run /replicant-lead:setup" >&2; exit 2; }

if [[ -f "$PROJECT/Gemfile" ]]; then
  BUNDLE_GEMFILE="$PROJECT/Gemfile" exec bundle exec ruby "$script" "$WS"
else
  exec ruby "$script" "$WS"
fi
