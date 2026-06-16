---
description: Instructor escape hatch — show the reference implementation for the current step.
---

Show the canonical reference for the current step. This is the **instructor's** demo tool (Antonio,
the reference) for when a learner is truly blocked or the session is out of time — not a shortcut to
skip the struggle.

1. Resolve the current step and its reference: look in `${CLAUDE_PLUGIN_ROOT}/curriculum/reference/`
   for the file named in the step's `reference:` pointer (these point at the repo's canonical
   servers, e.g. `first_socket.rb`, `rack_based_servers/server.rb`).
2. Show it, then **diff it against the learner's attempt** — frame their failed version as the
   "before" and walk the delta line by line. The learning is in the comparison, so don't just paste
   the answer and move on.
3. Note this reveal in the conversation so it's clear the learner saw the reference rather than
   deriving it.

Prefer `/c10k-dojo:hint` first. Only reveal after ~3 failed attempts with a skeleton, or for a live
instructor demo.
