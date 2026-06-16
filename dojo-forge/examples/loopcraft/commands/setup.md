---
description: One-time setup — verify Node and Ollama, create the initial Modelfile, check tooling. No npm packages needed — TypeScript runs natively.
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will
build (their `workspace/` will live here).

1. **Workspace:** create `./workspace/` if missing (the agent's only writable code dir).

2. **Node.js check:** verify Node 22+ is available — it runs `.ts` files natively (no transpiler, no flags).
   - `node --version` — should be v22 or higher.
   - `node -e "console.log(typeof fetch)"` — should print `function` (built-in fetch).
   - No `npm install`. No `package.json`. No `tsx`. No `--experimental-strip-types` flag.
   Node 22+ handles `.ts` natively and includes `fetch`, `node:readline/promises`, `node:fs/promises`,
   `node:path` — everything the dojo needs.

3. **Ollama check:** verify `ollama` is installed and running:
   - `ollama --version` (should show a version)
   - `curl http://localhost:11434/api/tags` (should list models, even if empty)
   - If no model is available, suggest: `ollama pull qwen3:8b` (or any model the learner prefers — the dojo works with any Ollama model).
   - The suggested default is `qwen3:8b` but ANY model works. Ask the learner which model they want to use and note it.

4. **Initial Modelfile:** create `workspace/Modelfile` with the base model and a simple SYSTEM prompt:
   ```
   FROM <model-name>
   SYSTEM You are a helpful assistant. Respond concisely.
   ```
   Replace `<model-name>` with the model the learner chose (or `qwen3:8b` as default).
   Build it: `ollama create loopcraft -f workspace/Modelfile`

5. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (Ollama API reference, Modelfile format, Open-Meteo cheatsheet, DuckDuckGo cheatsheet, and INDEX.md).
   Confirm `./docs/INDEX.md` exists afterward.

6. **Tooling check:** verify
   - `node --version` (Node 22+ for native TypeScript),
   - `ollama list` (should show the model they pulled).

7. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.loopcraft" && touch "${CLAUDE_PROJECT_DIR:-$PWD}/.loopcraft/.setup_done"`.
   (The SessionStart hook checks this sentinel — once it exists, opening Claude goes straight to
   tutoring instead of re-running setup.)

Report what's ready and what's missing, then move straight into **Step 1** (the SessionStart hook
already pointed you here; no need to wait for the learner to type `/loopcraft:start`).