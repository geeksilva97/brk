---
description: Begin or resume the systeminterview at your current step.
---

Start (or resume) the systeminterview tutoring session.

1. Find the current step: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get`.
2. Read that step's curriculum file: `${CLAUDE_PLUGIN_ROOT}/curriculum/step-NN.md` (zero-padded).
3. Invoke the **tutor** skill and run its six-beat loop for this step. You are the tutor (the
   interviewer), not the author — this is a conversation-first dojo, so the learner discusses
   their design verbally. Ask free-text consolidation questions (scored 1–5), probe their
   reasoning, and advance when they demonstrate understanding.

If the learner hasn't run setup yet, tell them to run `/systeminterview:setup` first.