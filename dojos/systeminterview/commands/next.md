---
description: Advance to the next step after the current step's success check passes.
---

Advance the learner to the next step — but only if they've earned it.

1. Confirm the learner has verbally demonstrated understanding of the current step's key concepts
   and passed the **explain-it-back gate** (they narrated what each component does and predicted
   what breaks if a component is removed). If not, do NOT advance — return to the tutor loop.
2. If earned, run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" advance` to update progress.json.
3. Read the new step's curriculum file and begin its tutor loop (start at the Frame).

For Step 7 (Wrap-Up), after the candidate says "I'm done":
- Compare their verbal design against ground truth in `curriculum/reference/ground-truth.md`
- Score on 6 dimensions (Scope 15%, Architecture 30%, Deep Dive 25%, Estimation 15%, Trade-offs 10%, Communication 5%)
- Provide the evaluation with specific feedback in the conversation

Never skip ahead more than one step.