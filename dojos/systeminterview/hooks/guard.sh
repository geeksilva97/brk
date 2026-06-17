#!/usr/bin/env bash
# PreToolUse guard — the "jail" enforced by the plugin itself.
#   guard.sh web    -> always deny (matcher only fires on WebFetch/WebSearch)
#   guard.sh bash   -> deny obvious web egress / dependency installs; allow everything else
#
# This is a conversation-first dojo — there are no spine files to protect.
# The learner discusses their design verbally; the tutor evaluates through dialogue.
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
    deny "The dojo is offline by design. Do not use WebFetch/WebSearch. Use first principles and the reference material in curriculum/reference/."
    ;;

  bash)
    # Deny external HTTP(S) egress (allow localhost-style hosts).
    urls="$(printf '%s' "$PAYLOAD" | grep -oE 'https?://[^[:space:]"'\''\\)]+' || true)"
    if [[ -n "$urls" ]]; then
      while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        host="$(printf '%s' "$u" | sed -E 's#^https?://([^/:]+).*#\1#')"
        case "$host" in
          localhost|127.0.0.1|0.0.0.0|::1|\[::1\]) : ;;
          *) deny "The dojo is offline. Outbound HTTP to ${host} is blocked. Use first principles and the reference material in curriculum/reference/." ;;
        esac
      done <<< "$urls"
    fi
    # Deny ad-hoc dependency installs.
    if printf '%s' "$PAYLOAD" | grep -Eq '(gem[[:space:]]+install|bundle[[:space:]]+add|npm[[:space:]]+install|pip[[:space:]]+install|cargo[[:space:]]+add|go[[:space:]]+get)[[:space:]]'; then
      deny "Installing dependencies is off-limits — this is a design interview dojo. No code, no dependencies."
    fi
    # otherwise allow
    exit 0
    ;;

  *)
    exit 0
    ;;
esac