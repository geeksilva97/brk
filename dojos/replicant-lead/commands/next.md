---
description: Advance to the next step once the trial passed and the learner earned it.
---

Advance the learner to the next step — but only if they've earned it.

1. Confirm all of these, or do NOT advance — return to the tutor loop for the current step:
   - the trial's success check passed (see the latest row in `.replicant-lead/results.csv`),
   - every decision row in the step's ADR has the learner's words in `Learner said`,
   - every unlisted choice was accepted, rejected, or promoted — the ADR matches the shipped code,
   - every consolidation question scored ≥ 3, and the learner passed the explain-it-back gate.
2. Report the ask count for the step.
3. If earned, run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" advance`.
4. Read the new step's curriculum file and begin its tutor loop at the incident. Do not summarize or
   preview it beyond its title.

Never skip ahead. If the learner asks to jump, remind them each incident lands on the system as
their decisions left it.
