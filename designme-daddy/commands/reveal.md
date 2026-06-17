---
description: Instructor escape hatch — show a model answer for the current phase.
---

Show a canonical model answer for the current phase. This is the **instructor's** demo tool for when a
learner is truly blocked or the session is out of time — not a shortcut to skip the struggle.

1. Resolve the current step and its reference: look in `${CLAUDE_PLUGIN_ROOT}/curriculum/reference/`
   for the file named in the step's `reference:` pointer (if the step has one). If the step's
   `reference:` is `-`, compose a concise model answer from the step's rubric and gotchas instead.
2. Show it, then **diff it against the learner's attempt** — frame their reasoning as the "before" and
   walk the delta decision by decision: what they had, what a strong answer adds, and *why*. The
   learning is in the comparison, so don't just state the model answer and move on.
3. Note this reveal in the conversation so it's clear the learner saw a model answer rather than
   reaching it themselves.

Prefer `/designme-daddy:hint` first. Only reveal after ~3 failed attempts with a scaffold, or for a
live instructor demo.
