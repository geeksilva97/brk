---
description: Give a scoped hint for the current step — never the full spine.
---

The learner is stuck. Give the **smallest** nudge that unblocks them, escalating only if needed:

1. **Point to the doc.** Name the exact bundle file and what to look for
   (e.g. "read `docs/man/fork.txt` — what does it say about inherited file descriptors?").
2. **Ask a leading question** that isolates the bug ("what does the *child* still have open?").
3. **Worked skeleton.** Only if 1–2 fail: provide the spine's *shape* with `# TODO` gaps — method
   calls and structure, but the learner fills the load-bearing expressions. This is NOT writing the
   spine; the `# TODO` lines are theirs.

Never paste the complete spine. If they're still blocked after a skeleton, suggest the instructor
demo via `/c10k-dojo:reveal`. The struggle is the point — protect it.
