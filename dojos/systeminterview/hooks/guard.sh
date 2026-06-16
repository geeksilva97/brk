#!/bin/bash
# Guard — for interview dojo, we allow all tools but block revealing ground truth
# The tutor skill handles enforcement (no drawing architecture for the candidate)

# Only block reads of the reference/ground-truth files by the candidate
# (the agent reads them for evaluation, but should not show them prematurely)

TOOL="$1"
TARGET="$2"

case "$TOOL" in
  Read|Write|Edit)
    # Block reading ground truth directly (agent should use /systeminterview:reveal)
    if echo "$TARGET" | grep -q "curriculum/reference/ground-truth"; then
      echo "BLOCKED: Use /systeminterview:reveal to see the reference design"
      exit 1
    fi
    ;;
esac

echo "ALLOWED"