---
description: Advance to the next phase after the current phase's rubric is met.
---

Advance the learner to the next phase — but only if they've earned it.

1. Confirm the current phase's **rubric** (its Success check) is met and the learner passed the
   **explain-it-back gate** (they narrated *why* their decisions are right and predicted what breaks if
   made differently). If not, do NOT advance — return to the tutor loop for the current phase.
2. If earned, run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" advance` to update progress.json.
3. Read the new step's curriculum file and begin its tutor loop (start at the Frame).

Never skip ahead more than one phase. If the learner asks to jump, remind them each phase builds on the
decisions made in the previous one — you can't design the data model before you know the requirements.
