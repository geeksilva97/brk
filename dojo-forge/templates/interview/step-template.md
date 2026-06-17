---
step: {{STEP_NUM}}
title: {{STEP_TITLE}}
spine: -
kind: {{STEP_KIND}}
reference: {{STEP_REFERENCE}}
---

# Step {{STEP_NUM}} — {{STEP_TITLE}}

<!-- NO-CODE / interview modality. The "spine" is the learner's REASONING, not a file.
     `spine:` is always `-`. The "Success check" is a RUBRIC the tutor scores against,
     not a runnable command. Everything else follows the standard step format. -->

## Frame
<!-- 1–3 sentences: what this step decides and why the previous step leaves it open.
     Sets up the thinking; do not lecture and do not quiz yet. -->
{{STEP_FRAME}}

## Teach the mechanisms
<!-- Before any reasoning: explain each NEW concept (one-line "what it is and why" or a leading
     question), point at the exact cheatsheet in the bundle, and name the RUBRIC — what a complete
     answer for this step must contain. Do not quiz here — teach. -->
{{STEP_MECHANISMS}}

<!-- OPTIONAL: if this step leans on facts/primitives the learner is NOT expected to derive,
     name the GIVEN black box here and point at its committed cheatsheet (docs/<thing>-cheatsheet.md).
     State it's provided whole so the learner doesn't feel they're missing prerequisites. -->
{{GIVEN_BLACKBOX}}

## Spine  (the learner reasons this out themselves — no code, no file)
<!-- Exactly what the learner must PRODUCE in their own words — the load-bearing decision(s) that ARE
     the lesson. Name the question to answer, the goal (what the decision must cover), and the shape at
     a high level. Then WAIT. -->
{{SPINE_INSTRUCTIONS}}

**Read first:** {{SPINE_DOCS}}

## Agent role
- `[explain]` {{ROLE_EXPLAIN}}
- `[scaffold]` {{ROLE_SCAFFOLD}}
- `[review]` {{ROLE_REVIEW}}

## Gotchas
<!-- Classic weak answers and misconceptions for THIS step only. Do NOT foreshadow later steps. -->
{{GOTCHAS}}

## Success check  (a RUBRIC, not a command)
<!-- There is no command to run. State what a complete, sound answer for this step must contain — the
     tutor scores the learner's reasoning against this. -->
{{SUCCESS_CHECK}}

The learner must explain *why* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the rubric is met)
<!-- Quizzes are NOT fixed questions. The tutor composes them in the moment from what the learner
     actually decided, where they struggled, and what the pressure-test surfaced. Angles must target
     the learner's OWN reasoning — never provided cheatsheets/given facts — and must not depend on a
     later step. Each question is open-ended; the tutor scores 1–5 and keeps asking until the answer
     lands (score ≥ 3). -->

**Quiz topic 1 — Diagnose:**
{{DIAGNOSE_ANGLE}}

**Quiz topic 2 — Design:**
{{DESIGN_ANGLE}}

**Quiz topic 3 — Reflect:**
{{REFLECT_ANGLE}}

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. {{NEXT_HINT}} Then point them to
**Step {{NEXT_STEP_NUM}}** and run `/{{PLUGIN_NAME}}:next`.
