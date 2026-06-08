---
description: Begin or resume the c10k-dojo at your current step.
---

Start (or resume) the c10k-dojo tutoring session.

1. Find the current step: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get` (the plugin root and a
   copy of this path were also provided in the session-start context if the variable is unset).
2. Read that step's curriculum file: `${CLAUDE_PLUGIN_ROOT}/curriculum/step-NN.md` (zero-padded).
3. Invoke the **tutor** skill and run its seven-beat loop for this step. You are the tutor, not the
   author — quiz with AskUserQuestion, make the learner type the spine, review, do not write the
   spine file.

If the curriculum file or the `docs/` bundle is missing, tell the learner to run
`/c10k-dojo:setup` first.
