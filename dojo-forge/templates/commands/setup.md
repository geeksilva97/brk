---
description: One-time setup — provision dependencies offline-safe and build the docs bundle.
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will
build (their `workspace/` will live here).

1. **Workspace:** create `./workspace/` if missing (the learner's only writable code dir).

2. **Dependencies (do this BEFORE jailing — it needs the network once):**
{{SETUP_DEPS}}

   After this the learner can run/build offline. The guard hook blocks ad-hoc installs afterward, so
   everything the curriculum needs must be installed here.

3. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (reference material, cheatsheets, INDEX.md). Confirm `./docs/INDEX.md` exists afterward.

4. **Tooling check:** verify the runtime dependencies are available:
{{SETUP_TOOLING}}

5. **Backend mode (local model via Ollama):** ask which model backs Claude Code — the
   **local-jailed** model (a local LLM served by **Ollama** or llama.cpp — a true air-gap, the
   default) or the **anthropic-api** easy-mode. For Ollama, make sure it's serving the model
   (`ollama pull llama3:8b`; it listens on `:11434`) and launch with `--model llama3:8b` (the
   `{{PLUGIN_NAME}}.sh` wrapper forwards it). Record the choice with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.
{{SETUP_EXTRA}}

6. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/{{STATE_DIR}}" && touch "${CLAUDE_PROJECT_DIR:-$PWD}/{{STATE_DIR}}/.setup_done"`.
   (The SessionStart hook checks this sentinel — once it exists, opening Claude goes straight to
   tutoring instead of re-running setup.)

Report what's ready and what's missing, then move straight into **Step 1** (the SessionStart hook
already pointed you here; no need to wait for the learner to type `/{{PLUGIN_NAME}}:start`).