#!/usr/bin/env bash
# PreToolUse guard — the "jail" for a LEAD-mode dojo (the learner leads, the agent executes).
#   guard.sh web    -> always deny (matcher only fires on WebFetch/WebSearch)
#   guard.sh bash   -> deny web egress / dependency installs, and the trial until the ADR's
#                      expected results are filled in
#   guard.sh spine  -> on lead steps, deny Write/Edit under workspace/ until the current step's ADR
#                      is complete (expected results included); on build steps, deny Write/Edit to
#                      the spine file
#
# Lead-mode inversion of the build-mode jail: the agent writes everything, including the ADR — it
# records the learner's decisions, it never makes them. That rule lives in the tutor skill (a hook
# can't tell whose idea a sentence was). What a hook CAN enforce is the order: decide, then build;
# commit to expected results, then run the trial.
#
# Reads the PreToolUse payload JSON on stdin. To DENY: print a JSON object with
# permissionDecision=deny and exit 0. To ALLOW: print nothing and exit 0.
set -uo pipefail

MODE="${1:-}"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
PAYLOAD="$(cat 2>/dev/null || true)"

ADR_HEADINGS=("Context" "Decision" "Alternatives" "Consequences" "Failure modes" "Expected results")

deny() { # deny <reason>
  # reason must contain no double quotes (kept simple to avoid a JSON lib)
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

kind="$("$ROOT/bin/dojo.sh" kind 2>/dev/null || true)"
spine="$("$ROOT/bin/dojo.sh" spine 2>/dev/null || true)"
adr="$PROJECT/$spine"

adr_missing() { # prints the first missing heading (or "file"); empty when complete
  local h
  [[ -s "$adr" ]] || { echo "file"; return; }
  for h in "${ADR_HEADINGS[@]}"; do
    grep -Eq "^##[[:space:]]+${h}([[:space:]]|$)" "$adr" || { echo "$h"; return; }
  done
}

expected_incomplete() { # true when the section is missing/empty or a list item has no number
  [[ -s "$adr" ]] || return 0
  local items
  items="$(awk '/^##[[:space:]]+Expected results/{on=1; next} /^##[[:space:]]/{on=0} on && /^[[:space:]]*[-*][[:space:]]/' "$adr")"
  [[ -z "$items" ]] && return 0
  printf '%s\n' "$items" | grep -vq '[0-9]' && return 0
  return 1
}

case "$MODE" in
  web)
    deny "The dojo is offline by design. Do not use WebFetch/WebSearch. Read the mounted docs bundle: open docs/INDEX.md and grep docs/ for what you need."
    ;;

  bash)
    urls="$(printf '%s' "$PAYLOAD" | grep -oE 'https?://[^[:space:]"'"'"'\\)]+' || true)"
    if [[ -n "$urls" ]]; then
      while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        host="$(printf '%s' "$u" | sed -E 's#^https?://([^/:]+).*#\1#')"
        case "$host" in
          localhost|127.0.0.1|0.0.0.0|::1|\[::1\]) : ;;
          *) deny "The dojo is offline. Outbound HTTP to ${host} is blocked. Only localhost is reachable." ;;
        esac
      done <<< "$urls"
    fi
    if printf '%s' "$PAYLOAD" | grep -Eq '(gem[[:space:]]+install|bundle[[:space:]]+add|npm[[:space:]]+install|pip[[:space:]]+install|cargo[[:space:]]+add|go[[:space:]]+get)[[:space:]]'; then
      deny "Installing dependencies is off-limits — the dependency set is pinned by setup."
    fi
    # No trial before expected results: the result is only worth something against a committed guess.
    # The incident repro (trial.sh <step> --repro) is part of the Frame and never blocked.
    if [[ "$kind" == "lead" ]] && printf '%s' "$PAYLOAD" | grep -q 'trial\.sh' \
       && ! printf '%s' "$PAYLOAD" | grep -q -- '--repro'; then
      if expected_incomplete; then
        deny "The trial is locked until the ADR has an Expected results section with a number on every item. Ask the learner for their numbers and record them; never propose numbers or ranges yourself."
      fi
    fi
    exit 0
    ;;

  spine)
    fp="$(printf '%s' "$PAYLOAD" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)".*/\1/')"
    [[ -z "$fp" ]] && exit 0
    # The grader and the fault injection are GIVEN: a build that edits them can pass any trial.
    case "$fp" in
      "$ROOT"/*|*/workspace/bin/cluster|*/workspace/bin/link|*/workspace/lib/link.rb|*/workspace/lib/wire.rb)
        deny "${fp##*/} is part of the GIVEN harness (the trial, the cluster runner, the fault link, the wire format). Do not modify it — change the system under test instead."
        ;;
    esac
    if [[ "$kind" == "lead" ]]; then
      case "$fp" in
        */workspace/*|workspace/*)
          missing="$(adr_missing)"
          if [[ "$missing" == "file" ]]; then
            deny "No code yet: ${spine} does not exist. Decide, then build — get the decisions from the learner and record them in the ADR first."
          elif [[ -n "$missing" ]]; then
            deny "No code yet: ${spine} is missing its ## ${missing} section. Get it from the learner and record it; do not fill it in yourself."
          elif expected_incomplete; then
            deny "No code yet: the Expected results in ${spine} are the acceptance criteria, and not every item has a number. Ask the learner for them; never propose numbers or ranges yourself."
          fi
          ;;
      esac
    elif [[ -n "$spine" && "$fp" == *"$spine" ]]; then
      deny "${spine} is the learner's spine for this step. Do not write or edit it."
    fi
    exit 0
    ;;

  *)
    exit 0
    ;;
esac
