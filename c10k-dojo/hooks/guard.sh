#!/usr/bin/env bash
# PreToolUse guard — the "jail" enforced by the plugin itself.
#   guard.sh web    -> always deny (matcher only fires on WebFetch/WebSearch)
#   guard.sh bash   -> deny obvious web egress / gem installs; allow everything else
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
    deny "The dojo is offline by design. Do not use WebFetch/WebSearch. Read the mounted docs bundle: open docs/INDEX.md and grep docs/ for the API or man page you need."
    ;;

  bash)
    # Deny external HTTP(S) egress (allow localhost-style hosts and the bench container name).
    urls="$(printf '%s' "$PAYLOAD" | grep -oE 'https?://[^[:space:]"'"'"'\\)]+' || true)"
    if [[ -n "$urls" ]]; then
      while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        host="$(printf '%s' "$u" | sed -E 's#^https?://([^/:]+).*#\1#')"
        case "$host" in
          localhost|127.0.0.1|0.0.0.0|::1|\[::1\]|target|c10k-target) : ;;
          *) deny "The dojo is offline. Outbound HTTP to ${host} is blocked. Use the mounted docs bundle (docs/INDEX.md); only localhost is reachable for testing your own server." ;;
        esac
      done <<< "$urls"
    fi
    # Deny ad-hoc gem installs — the gem set is pinned in the benchmark image.
    if printf '%s' "$PAYLOAD" | grep -Eq '(gem[[:space:]]+install|bundle[[:space:]]+add)[[:space:]]'; then
      deny "Installing gems is off-limits — the dojo uses a pinned set (rack, protocol-http1, protocol-http, async). Build from stdlib + those. If you think you need another gem, that is usually a sign to reach for a Ruby primitive instead."
    fi
    # otherwise allow
    exit 0
    ;;

  spine)
    spine="$("$ROOT/bin/dojo.sh" spine 2>/dev/null || true)"
    # Nothing to protect for bench/no-spine steps.
    [[ -z "$spine" || "$spine" == "workspace/" || "$spine" == */ ]] && exit 0
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
