---
description: Instructor escape hatch — show the reference implementation for the current step.
---

Show the canonical reference for the current step. This is the **instructor's** demo tool — for when
a learner is truly blocked or the session is out of time — not a shortcut to skip the struggle.

1. Resolve the current step and its reference. Each step's curriculum file names a `reference:` file
   under `${CLAUDE_PLUGIN_ROOT}/curriculum/reference/`:
   - All steps reference `agent.ts` (the progressive implementation).
   - Step 1 also references `Modelfile` (the initial system prompt).
2. Show it, then **diff it against the learner's attempt** — frame their version as the "before" and
   walk the delta line by line. The learning is in the comparison, so don't just paste the answer and
   move on.
3. Note this reveal in the conversation so it's clear the learner saw the reference rather than
   deriving it.

Prefer `/loopcraft:hint` first. Only reveal after ~3 failed attempts with a skeleton, or for a
live instructor demo.
