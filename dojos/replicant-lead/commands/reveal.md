---
description: Instructor escape hatch — show one reference set of decisions for the current step.
---

Show the reference for the current step. This is the **instructor's** tool for a learner who is truly
blocked, or for the debrief after the step — not a shortcut past deciding.

1. Resolve the step's reference in `${CLAUDE_PLUGIN_ROOT}/curriculum/reference/` (the step file's
   `reference:` pointer; if it is `-`, say there is none and prefer `/replicant-lead:hint`).
2. Show the **decisions** it makes first (its header comment), then the code.
3. Compare it with the learner's ADR **decision by decision**: where they differ, ask which one holds
   up better under the step's trial and failure modes. A different decision is not a wrong one — the
   reference is one defensible set, not the answer key.
4. Note in the conversation that the learner saw the reference, and record it in the ADR under
   `## Context` so the provenance stays honest.
