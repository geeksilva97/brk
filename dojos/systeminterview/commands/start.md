---
description: Begin or resume the systeminterview at your current step.
---

Start (or resume) the systeminterview tutoring session.

1. Find the current step: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get` (the plugin root and a
   copy of this path were also provided in the session-start context if the variable is unset).
2. Read that step's curriculum file: `${CLAUDE_PLUGIN_ROOT}/curriculum/step-NN.md` (zero-padded).
3. Invoke the **tutor** skill and run its six-beat loop for this step. You are the tutor (the
   interviewer), not the author — ask free-text consolidation questions (scored 1–5), make the
   learner type the spine, review, do not write the spine file.

If the curriculum file or the `docs/` bundle is missing, tell the learner to run
`/systeminterview:setup` first.