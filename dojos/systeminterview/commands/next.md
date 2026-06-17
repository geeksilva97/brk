---
description: Advance to the next step after the current step's success check passes.
---

Advance the learner to the next step — but only if they've earned it.

1. Confirm the current step's **success check** passed and the learner passed the **explain-it-back
   gate** (they narrated what their design does and predicted what breaks if a component is
   removed). If not, do NOT advance — return to the tutor loop for the current step.
2. If earned, run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" advance` to update progress.json.
3. Read the new step's curriculum file and begin its tutor loop (start at the Frame).

For Step 7 (Wrap-Up), after the candidate says "I'm done":
- Read all candidate files in `workspace/`
- Compare against ground truth in `curriculum/reference/ground-truth.md`
- Score on 6 dimensions (Scope 15%, Architecture 30%, Deep Dive 25%, Estimation 15%, Trade-offs 10%, Communication 5%)
- Write evaluation to `workspace/evaluation.md`
- Provide the evaluation with specific feedback

Never skip ahead more than one step. If the learner asks to jump, remind them each step is built
from the previous one's.