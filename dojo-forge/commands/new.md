---
description: Scaffold a brand-new tutored dojo plugin for any topic — either by interview or by self-service research.
---

Generate a new tutored coding-dojo plugin from scratch. Two modes:

**Self-service** (topic provided): if `$ARGUMENTS` is non-empty, treat it as the topic. Invoke the
**forge** skill in **SELF-SERVICE** mode — use `WebSearch` to research the topic, synthesize a spine
progression (4–12 milestones), determine the jail constraints and given black boxes, then present a
compact spec for the instructor to confirm before scaffolding. No interview questions needed.

**Interview** (no topic): if `$ARGUMENTS` is empty, invoke the **forge** skill in **INTERVIEW** mode —
ask the instructor questions via `AskUserQuestion` to gather: the topic, the language/runtime, the
plugin name, the step-by-step spine progression (4–12 milestones), the constraint/jail, the
win-condition, and any "given black box" the learner receives vs must derive.

After either mode converges on a spec, **scaffold** the new `<name>-dojo/` plugin directory by copying
the generic templates from `${CLAUDE_PLUGIN_ROOT}/templates/` (substituting placeholders) and
generating `curriculum/steps.tsv` + `step-NN.md` files, a tailored `/setup`, cheatsheets, the root
`<name>-dojo.sh` launcher, and a README. Then **validate** with `claude plugin validate <name>-dojo`
and `bash -n` on every shell file (including the launcher).

Arguments (optional, triggers self-service mode if present): $ARGUMENTS