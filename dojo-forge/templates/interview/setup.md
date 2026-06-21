---
description: One-time setup — build the offline cheatsheet bundle (no dependencies to install).
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will work
(their per-project `{{STATE_DIR}}/` state will live here). This is a **no-code** dojo, so setup is
light: there is nothing to compile, vendor, or install — the only artifact is the offline cheatsheet
bundle the learner may consult.

1. **Dependencies:** none. This dojo is pure conversation — there is nothing to install. Skip straight
   to the docs bundle.

2. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (the cheatsheets + INDEX.md). Confirm `./docs/INDEX.md` exists afterward. This must run
   while the network is available — afterward the guard hook jails the session offline so the learner
   reasons from these cheatsheets and first principles.

3. **Tooling check:** nothing to verify — this dojo needs no runtime or tooling. Just confirm
   `./docs/INDEX.md` and the cheatsheets are present (`ls ./docs`).

4. **Backend mode (local model via Ollama):** ask which model backs Claude Code — the
   **local-jailed** model (a local LLM served by **Ollama** or llama.cpp — a true air-gap, the
   default) or the **anthropic-api** easy-mode. For Ollama, make sure it's serving the model
   (`ollama pull llama3:8b`; it listens on `:11434`) and launch with `--model llama3:8b` (the
   `{{PLUGIN_NAME}}.sh` wrapper forwards it). Record the choice with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.
{{SETUP_EXTRA}}

5. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/{{STATE_DIR}}" && touch "${CLAUDE_PROJECT_DIR:-$PWD}/{{STATE_DIR}}/.setup_done"`.

Report what's ready, then move straight into **Step 1** (the SessionStart hook already pointed you here;
no need to wait for the learner to type `/{{PLUGIN_NAME}}:start`).
