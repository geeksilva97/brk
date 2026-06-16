---
description: Advance to the next step after the current step's success check passes.
---

Advance the learner to the next step — but only if they've earned it.

1. Confirm the current step's **success check** passed and the learner passed the **explain-it-back
   gate** (they narrated what the code does and predicted what breaks if a piece is removed). If
   not, do NOT advance — return to the tutor loop for the current step.
2. If earned, run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" advance` to update progress.json.
3. Read the new step's curriculum file and begin its tutor loop (start at the Frame).

Never skip ahead more than one step. The arc is: Modelfile → tool definitions → parse + execute
weather → inject + re-prompt → the agent loop → web search → skills as tools.
