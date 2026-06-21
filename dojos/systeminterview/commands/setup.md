---
description: "One-time setup for the System Design Interview dojo"
---

One-time setup — prepare the project directory for the dojo. This is a **conversation-first** dojo
with no workspace or file writing.

1. **State directory:** create `.systeminterview/` in the project dir if missing
   (the state helper and hooks use it for progress tracking):
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview"`

2. **Backend mode (local model via Ollama):** ask which model backs Claude Code — the
   **local-jailed** model (a local LLM served by **Ollama** or llama.cpp — a true air-gap, the
   default) or the **anthropic-api** easy-mode. For Ollama, make sure it's serving the model
   (`ollama pull llama3:8b`; it listens on `:11434`) and launch with `--model llama3:8b` (the
   `systeminterview.sh` wrapper forwards it). Record the choice with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.

3. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `touch "${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview/.setup_done"`

Report what's ready, then move straight into **Step 1** (the SessionStart hook already pointed you here).