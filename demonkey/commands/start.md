---
description: Begin or resume the demonkey at your current step.
---

Start (or resume) the demonkey tutoring session.

1. Find the current step: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get` (the plugin root and a
   copy of this path were also provided in the session-start context if the variable is unset).
2. Read that step's curriculum file: `${CLAUDE_PLUGIN_ROOT}/curriculum/step-NN.md` (zero-padded).
3. Invoke the **tutor** skill and run its six-beat loop for this step. You are the tutor, not the
   author — teach the mechanisms and point at the docs, make the learner type the spine, review,
   verify locally, *then* quiz with AskUserQuestion to consolidate. Never quiz a primitive before the
   learner has implemented it, and never write the spine file.

If the curriculum file or the `docs/` bundle is missing, tell the learner to run
`/demonkey:setup` first.
