---
description: "One-time setup for the System Design Interview dojo"
---

One-time setup — prepare the project directory for the dojo. This is a **conversation-first** dojo
with no workspace or file writing.

1. **State directory:** create `.systeminterview/` in the project dir if missing
   (the state helper and hooks use it for progress tracking):
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview"`

2. **Backend mode:** ask the learner whether they're running the **conversation** mode
   (default, pure dialogue) or prefer a different mode, and record it with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <conversation|anthropic-api>`.

3. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `touch "${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview/.setup_done"`

Report what's ready, then move straight into **Step 1** (the SessionStart hook already pointed you here).