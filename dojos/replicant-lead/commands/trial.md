---
description: Run the current step's trial against the learner's system and compare it with their expected results.
---

Run the graded trial for the current step (beat 7).

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/trial.sh" "$("${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get)"` from the
   project dir. The guard blocks it until the ADR's `## Expected results` has a number on every item
   — if it is blocked, go back to the learner for the missing numbers; never fill them in.
2. The post-trial hook records the `TRIAL_RESULT` line in `.replicant-lead/results.csv` and hands you
   the learner's expected results beside it. Show both, item by item.
3. Do not explain the gaps. Ask the learner to explain the biggest one first.

The trial is the plugin's. Never write, patch, or wrap a grader, and never change the GIVEN harness
(`bin/cluster`, `bin/link`, `lib/link.rb`, `lib/wire.rb`) to make a trial pass.
