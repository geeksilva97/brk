---
description: "Start or resume the System Design Interview dojo at the current step"
---

# Start Command

1. Read the current step from `bin/dojo.sh get` (defaults to step 1 if no progress file exists)
2. Read the step's curriculum file: `curriculum/step-{N}.md`
3. Invoke the **tutor** skill and run its interview loop for this step. You are the interviewer, not the
   candidate — ask probing questions, make them design, review their architecture, then ask free-text
   consolidation questions scored 1–5. Never draw the architecture for them.

If the curriculum file is missing, tell the learner to run
`/systeminterview:setup` to provision the environment first.