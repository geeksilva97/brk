---
description: Interview the instructor and scaffold a brand-new tutored dojo plugin for any topic.
---

Generate a new tutored coding-dojo plugin from scratch. Invoke the **forge** skill and run its full
flow:

1. **Interview** the instructor using the `AskUserQuestion` tool (never plain-text questions) to
   gather: the topic, the language/runtime, the plugin name, the step-by-step spine progression
   (4–12 milestones), the constraint/jail, the win-condition, and any "given black box" the learner
   receives vs must derive.
2. **Scaffold** the new `<name>-dojo/` plugin directory in the current project by copying the
   generic templates from `${CLAUDE_PLUGIN_ROOT}/templates/` (substituting placeholders) and
   generating `curriculum/steps.tsv` + `step-NN.md` files, a tailored `/setup`, and a README.
3. **Validate** the output with `claude plugin validate <name>-dojo` and `bash -n` on every shell
   file, then report the file tree and validation results.

If the instructor passed any arguments after the command, treat them as the topic and use them to
pre-seed the first interview question. Otherwise start the interview from the top.

Arguments (optional): $ARGUMENTS
