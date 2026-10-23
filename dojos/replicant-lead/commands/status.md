---
description: Show dojo progress — current step, completed steps, and every trial against its expected results.
---

Show the learner where they are.

1. Progress: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" status` and render it readably — current step
   (with title) and completed steps.
2. Show the steps in `${CLAUDE_PLUGIN_ROOT}/curriculum/steps.tsv` with a marker on the current one.
   Titles only — no descriptions of steps not yet reached.
3. If `.replicant-lead/results.csv` exists, render each trial as a table, and for the current step
   put the learner's `## Expected results` (from its ADR) beside the measured values.
