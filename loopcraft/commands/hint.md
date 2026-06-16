---
description: Give a scoped hint for the current step — never the full spine.
---

The learner is stuck. Give the **smallest** nudge that unblocks them, escalating only if needed:

1. **Point to the doc.** Name the exact bundle file and what to look for
   (e.g. "read `docs/ollama-api.md` — what does the chat endpoint expect?", or
   "read `docs/open-meteo-cheatsheet.md` — what parameters does the forecast endpoint take?").
2. **Ask a leading question** that isolates the bug ("what does parseToolCalls return if the
   model wraps JSON in backticks?", "why does the conversation need the assistant's tool-call
   message?").
3. **Worked skeleton.** Only if 1–2 fail: provide the function's *shape* with `// TODO` gaps —
   function signatures and structure, but the learner fills the load-bearing expressions. This
   is NOT writing the spine; the `// TODO` lines are theirs.

Never paste the complete spine. If they're still blocked after a skeleton, suggest the instructor
demo via `/loopcraft:reveal`.
