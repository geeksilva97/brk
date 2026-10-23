---
description: Begin or resume the replicant-lead dojo at your current step.
---

Start (or resume) the replicant-lead session.

1. Find the current step: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get`.
2. Read that step's curriculum file: `${CLAUDE_PLUGIN_ROOT}/curriculum/step-NN.md` (zero-padded).
3. Invoke the **tutor** skill and run its eight beats for this step, starting at the incident and its
   live repro. You write the ADR and the code; the learner makes every decision. If an ADR for this
   step already exists, resume at the first beat it hasn't completed instead of starting over.

If `workspace/` or the `docs/` bundle is missing, run `/replicant-lead:setup` first.
