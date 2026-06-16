---
step: {{STEP_NUM}}
title: {{STEP_TITLE}}
spine: {{STEP_SPINE}}
kind: {{STEP_KIND}}
reference: {{STEP_REFERENCE}}
---

# Step {{STEP_NUM}} — {{STEP_TITLE}}

## Frame
<!-- 1–3 sentences: the problem this step solves and why the previous stage is inadequate.
     Sets up the build; do not lecture and do not quiz yet. -->
{{STEP_FRAME}}

## Teach the mechanisms
<!-- Before any code: explain each NEW concept (one-line "what it does and why" or a leading
     question), point at the exact doc in the bundle, and name how the learner will verify it
     ("you'll see X in the output" or "you'll be able to Y"). Do not quiz here — teach. -->
{{STEP_MECHANISMS}}

<!-- OPTIONAL: if this step relies on something the learner is NOT expected to know up front,
     name the GIVEN black box here and point at its committed cheatsheet (docs/<thing>-cheatsheet.md).
     State it's provided whole, not derived, so the learner doesn't feel they're missing
     prerequisites. -->
{{GIVEN_BLACKBOX}}

## Spine  (the learner types `{{STEP_SPINE}}`, ~{{SPINE_LINES}} lines)
<!-- Exactly what the learner types by hand — the load-bearing lines that ARE the lesson. Name the
     primitives to use, the goal (what it must do), and the shape at a high level. Then WAIT. -->
{{SPINE_INSTRUCTIONS}}

**Read first:** {{SPINE_DOCS}}

## Agent role
- `[explain]` {{ROLE_EXPLAIN}}
- `[glue]` {{ROLE_GLUE}}
- `[scaffold]` {{ROLE_SCAFFOLD}}
- `[review]` {{ROLE_REVIEW}}

## Gotchas
{{GOTCHAS}}

## Success check
<!-- Concrete runnable command(s) the learner runs to verify this step works, plus what they
     should observe in the output. This is the local win-condition. -->
{{SUCCESS_CHECK}}

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- Quizzes are NOT fixed questions. They are generated in the moment by the tutor based on:
     - What the learner actually coded (not a hypothetical)
     - Where they struggled (mistakes caught in review become quiz material)
     - What they observed (reference real output, not idealized)
     
     The topics below are ANGLES to quiz from, not verbatim questions. The tutor composes
     each quiz at runtime, drawing distractors from the gotchas above and the learner's
     actual mistakes during review. Each question asks the learner to explain in their own words;
     the tutor scores 1–5 and gives feedback. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count; no advancement without understanding. -->

**Quiz topic 1 — Diagnose:**
<!-- What angle to quiz from: e.g. "Why does X happen when Y?" or "What breaks if you remove Z?"
     The tutor composes the actual question based on what the learner built and observed. -->
{{DIAGNOSE_ANGLE}}

**Quiz topic 2 — Design:**
<!-- What angle to quiz from: e.g. "How would you extend X to handle Y?" or "Why is the API shaped this way?" -->
{{DESIGN_ANGLE}}

**Quiz topic 3 — Reflect:**
<!-- What angle to quiz from: e.g. "What's the one insight that makes this concept click?" or
     "How does this change the mental model from the previous step?" -->
{{REFLECT_ANGLE}}

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. {{NEXT_HINT}} Then point them to
**Step {{NEXT_STEP_NUM}}** and run `/{{PLUGIN_NAME}}:next`.