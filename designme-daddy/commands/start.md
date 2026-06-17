---
description: Begin or resume the designme-daddy interview at your current step.
---

Start (or resume) the designme-daddy system-design interview session.

1. Find the current step: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get` (the plugin root and a
   copy of this path were also provided in the session-start context if the variable is unset).
2. Read that step's curriculum file: `${CLAUDE_PLUGIN_ROOT}/curriculum/step-NN.md` (zero-padded).
3. Invoke the **tutor** skill and run its six-beat loop for this phase. You are the interviewer and
   tutor, not the author of the design — make the learner produce the reasoning themselves, review it,
   pressure-test it, then ask free-text consolidation questions (scored 1–5). There is no code and no
   file to write; never hand over the design.

If the curriculum file or the `docs/` bundle is missing, tell the learner to run
`/designme-daddy:setup` first.
