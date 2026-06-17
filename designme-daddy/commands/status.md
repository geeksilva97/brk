---
description: Show interview progress — current phase, completed phases, backend mode.
---

Show the learner where they are.

1. Progress: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" status` and render it readably — current phase
   (with title), completed phases, backend mode.
2. Read the step table (`${CLAUDE_PLUGIN_ROOT}/curriculum/steps.tsv`) and show the full 8-phase ramp
   with a marker on where the learner is, so the path ahead is visible.
3. If a notes file exists in the project's state dir (e.g. a running design summary the learner asked
   you to keep), render it as a short recap of the decisions made so far.
