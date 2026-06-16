---
description: Show dojo progress — current step, completed steps, backend mode.
---

Show the learner where they are.

1. Progress: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" status` and render it readably — current step
   (with title), completed steps, backend mode.
2. Read the step table (`${CLAUDE_PLUGIN_ROOT}/curriculum/steps.tsv`) and show the full ramp with a
   marker on where the learner is, so the path ahead is visible.
3. If a results file exists in the project's state dir (created by a topic-specific check hook, if
   any), render it as a table.
