---
description: Instructor escape hatch — show the reference implementation for the current step.
---

Show the canonical reference for the current step. This is the **instructor's** demo tool — for when
a learner is truly blocked or the session is out of time — not a shortcut to skip the struggle.

1. Resolve the current step and its reference. Each step's curriculum file names a `reference:` file
   under `${CLAUDE_PLUGIN_ROOT}/curriculum/reference/`:
   - Step 1 → `echo.rb`
   - Step 2 → `rack_server.rb` (+ `rack_env.rb` glue)
   - Step 4 → `fork_echo.rb`
   - Step 5 → `prefork.rb`
   - Step 6 → `master.rb`
   - Step 7 → `unicorn_like.rb`
   (Step 3 has no spine — it's the "see one server block" demo.)
2. Show it, then **diff it against the learner's attempt** — frame their version as the "before" and
   walk the delta line by line. The learning is in the comparison, so don't just paste the answer and
   move on.
3. Note this reveal in the conversation so it's clear the learner saw the reference rather than
   deriving it.

Prefer `/demonkey:hint` first. Only reveal after ~3 failed attempts with a skeleton, or for a
live instructor demo. The `unicorn_like.rb` USR2 re-exec with the inherited socket fd is the hardest
code in the course — a reveal there is expected.
