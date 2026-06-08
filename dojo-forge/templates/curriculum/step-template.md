---
step: {{STEP_NUM}}
title: {{STEP_TITLE}}
spine: {{STEP_SPINE}}
kind: {{STEP_KIND}}
reference: {{STEP_REFERENCE}}
---

# Step {{STEP_NUM}} — {{STEP_TITLE}}

## Frame
<!-- 1–3 sentences: the problem this step solves and why the previous stage is inadequate. Sets up
     the first question; do not lecture. -->
{{STEP_FRAME}}

## Diagnose-quiz  (AskUserQuestion)
**Question:** {{DIAGNOSE_QUESTION}}
- ✅ **{{DIAGNOSE_CORRECT}}** <!-- confirm + the one nuance to add -->
- ❌ "{{DIAGNOSE_WRONG_1}}" → <!-- the targeted correction this misconception needs -->
- ❌ "{{DIAGNOSE_WRONG_2}}" → <!-- correction -->

## Design-quiz  (AskUserQuestion)
**Question:** {{DESIGN_QUESTION}}
- ✅ **{{DESIGN_CORRECT}}**
- ❌ "{{DESIGN_WRONG_1}}" → <!-- the classic bug this reveals -->
- ❌ "{{DESIGN_WRONG_2}}" → <!-- correction -->

<!-- OPTIONAL: if the step relies on something the learner is NOT expected to know up front, name the
     GIVEN black box here and point at its committed cheatsheet (docs/<thing>-cheatsheet.md). State
     it's provided whole, not derived, so the learner doesn't feel they're missing prerequisites. -->
{{GIVEN_BLACKBOX}}

## Spine  (the learner types `{{STEP_SPINE}}`, ~{{SPINE_LINES}} lines)
<!-- Exactly what the learner types by hand — the load-bearing lines that ARE the lesson. Name the
     primitives to use and which docs to read first. -->
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
{{SUCCESS_CHECK}}

The learner must explain *why* it behaves this way before the step counts as done.

## Reflect-quiz  (AskUserQuestion)
**Question:** {{REFLECT_QUESTION}}
- ✅ **{{REFLECT_CORRECT}}**
- ❌ "{{REFLECT_WRONG_1}}" → <!-- correction -->
- ❌ "{{REFLECT_WRONG_2}}" → <!-- correction -->

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. {{NEXT_HINT}} Then point them to
**Step {{NEXT_STEP_NUM}}** and run `/{{PLUGIN_NAME}}:next`.
