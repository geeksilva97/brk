#!/usr/bin/env bash
# PreToolUse guard — the "jail" enforced by the plugin itself.
#   guard.sh web    -> always deny (matcher only fires on WebFetch/WebSearch)
#   guard.sh bash   -> deny obvious web egress / npm installs; allow everything else
#   guard.sh spine  -> deny Write/Edit to the CURRENT step's spine file (the learner types it)
#
# Reads the PreToolUse payload JSON on stdin. To DENY: print a JSON object with
# permissionDecision=deny and exit 0. To ALLOW: print nothing and exit 0.
set -uo pipefail

MODE="${1:-}"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PAYLOAD="$(cat 2>/dev/null || true)"

deny() { # deny <reason>
  # reason must contain no double quotes (kept simple to avoid a JSON lib)
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

case "$MODE" in
  web)
    deny "The dojo is offline by design. Do not use WebFetch/WebSearch. Read the mounted docs bundle: open docs/INDEX.md and grep docs/ for the API reference or cheatsheet you need."
    ;;

  bash)
    # Deny external HTTP(S) egress (allow localhost — that is where
    # the learner's own agent calls Ollama, and where Open-Meteo is reached from).
    urls="$(printf '%s' "$PAYLOAD" | grep -oE 'https?://[^[:space:]"'\'')]+' || true)"
    if [[ -n "$urls" ]]; then
      while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        host="$(printf '%s' "$u" | sed -E 's#^https?://([^/:]+).*#\1#')"
        case "$host" in
          localhost|127.0.0.1|0.0.0.0|::1|\[::1\]) : ;;
          *) deny "The dojo is offline. Outbound HTTP to ${host} is blocked. Use the mounted docs bundle (docs/INDEX.md); only localhost is reachable for calling Ollama and testing your agent." ;;
        esac
      done <<< "$urls"
    fi
    # Deny npm installs — the dojo uses native TypeScript only (Node 22+ runs .ts directly, no packages needed).
    # No npm packages at all — not even @types/node or tsx.
    if printf '%s' "$PAYLOAD" | grep -Eq '(npm[[:space:]]+install|npm[[:space:]]+add|npm[[:space:]]+i |npx[[:space:]]+create|yarn[[:space:]]+add|pnpm[[:space:]]+add|bun[[:space:]]+add)[[:space:]]'; then
      deny "Installing npm packages is off-limits — the dojo uses TypeScript native features only (Node 22+ runs .ts directly, built-in fetch, node:* imports). No packages needed. If you think you need one, reach for the stdlib."
    fi
    # otherwise allow
    exit 0
    ;;

  spine)
    spine="$("$ROOT/bin/dojo.sh" spine 2>/dev/null || true)"
    # Nothing to protect for demo/no-spine steps.
    [[ -z "$spine" || "$spine" == "-" || "$spine" == "workspace/" || "$spine" == */ ]] && exit 0
    fp="$(printf '%s' "$PAYLOAD" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')"
    [[ -z "$fp" ]] && exit 0
    case "$fp" in
      *"$spine")
        deny "${spine} is the learner's spine for this step — the lines that ARE the lesson. Do not write or edit it. Instead: explain the relevant docs, let the learner type it, then review by pointing at specific lines. (You may write the glue files named in the step.)"
        ;;
    esac
    exit 0
    ;;

  *)
    exit 0
    ;;
esac