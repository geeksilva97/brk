#!/usr/bin/env bash
# PreToolUse guard — the "jail" enforced by the plugin itself.
#   guard.sh web    -> always deny (matcher only fires on WebFetch/WebSearch)
#   guard.sh bash   -> deny obvious web egress / dependency installs; allow everything else
#   guard.sh spine  -> deny Write/Edit to the CURRENT step's spine file (the learner types it)
#
# NOTE: this is a NO-CODE dojo. Every step's spine is "-", so the `spine` branch is a
# no-op (there is no file to protect — the learner's "spine" is their verbal design).
# The web branch is the load-bearing jail here: it keeps the interview offline so the
# learner reasons from first principles and the bundled cheatsheets, not a web search.
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
    deny "The dojo is offline by design. Do not use WebFetch/WebSearch. Reason from first principles and the mounted docs bundle: open docs/INDEX.md and grep docs/ for the cheatsheet you need (latency numbers, capacity math, building blocks, geospatial)."
    ;;

  bash)
    # Deny external HTTP(S) egress (allow localhost-style hosts).
    urls="$(printf '%s' "$PAYLOAD" | grep -oE 'https?://[^[:space:]"'"'"'\\)]+' || true)"
    if [[ -n "$urls" ]]; then
      while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        host="$(printf '%s' "$u" | sed -E 's#^https?://([^/:]+).*#\1#')"
        case "$host" in
          localhost|127.0.0.1|0.0.0.0|::1|\[::1\]) : ;;
          *) deny "The dojo is offline. Outbound HTTP to ${host} is blocked. Use the mounted docs bundle (docs/INDEX.md); only localhost is reachable." ;;
        esac
      done <<< "$urls"
    fi
    # Deny ad-hoc dependency installs.
    if printf '%s' "$PAYLOAD" | grep -Eq '(gem[[:space:]]+install|bundle[[:space:]]+add|npm[[:space:]]+install|pip[[:space:]]+install|cargo[[:space:]]+add|go[[:space:]]+get)[[:space:]]'; then
      deny "Installing dependencies is off-limits. There are no dependencies in this dojo — it is pure conversation. If you reach for a package, that is a sign you are trying to write code; this is a no-code system-design interview."
    fi
    # otherwise allow
    exit 0
    ;;

  spine)
    spine="$("$ROOT/bin/dojo.sh" spine 2>/dev/null || true)"
    # Nothing to protect for no-spine steps (every step here is no-spine: spine == "-").
    [[ -z "$spine" || "$spine" == "-" || "$spine" == "workspace/" || "$spine" == */ ]] && exit 0
    fp="$(printf '%s' "$PAYLOAD" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')"
    [[ -z "$fp" ]] && exit 0
    case "$fp" in
      *"$spine")
        deny "${spine} is the learner's spine for this step. Do not write or edit it. Instead: explain, let the learner produce it, then review by pointing at the specifics."
        ;;
    esac
    exit 0
    ;;

  *)
    exit 0
    ;;
esac
