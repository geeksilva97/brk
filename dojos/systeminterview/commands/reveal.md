---
description: "Show the reference design for the current step"
---

# Reveal Command

Show the ground truth reference for the current step:

1. Read the current step from `bin/dojo.sh get`
2. Read the reference file specified in the step's frontmatter (`reference` field)
3. Read `curriculum/reference/ground-truth.md` for the complete reference
4. Present the relevant section to the candidate
5. Compare against what the candidate has in their `workspace/` files
6. Highlight what they got right and what they missed

Only use this as a last resort or after the candidate has completed the step and wants to compare notes.