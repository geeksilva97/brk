---
description: "Advance to the next step after the candidate passes the success check and explain-it-back gate"
---

# Next Command

1. Verify the candidate has completed the current step's success check
2. Ask the candidate to explain their design back in their own words (explain-it-back gate)
3. If they pass both:
   a. Run `bin/dojo.sh advance` to increment the step counter
   b. Read the next step's curriculum file: `curriculum/step-{N+1}.md`
   c. Present the next step's Frame section
4. If they don't pass:
   a. Identify what's missing or incorrect
   b. Guide them to fix it before advancing
   c. Do NOT advance until success check is satisfied

For Step 7 (Wrap-Up), after the candidate says "I'm done":
- Read all candidate files in `workspace/`
- Compare against ground truth in `curriculum/reference/ground-truth.md`
- Score on 6 dimensions (Scope 15%, Architecture 30%, Deep Dive 25%, Estimation 15%, Trade-offs 10%, Communication 5%)
- Write evaluation to `workspace/evaluation.md`
- Provide the evaluation with specific feedback