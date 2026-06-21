---
description: One-time setup — verify Node and Ollama, create workspace, copy utils.ts, build the initial Modelfile. No npm packages needed — TypeScript runs natively.
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will
build (their `workspace/` will live here).

1. **Workspace:** create `./workspace/` if missing (the agent's only writable code dir).

2. **Copy utils.ts:** the utility scaffolding must exist in `workspace/utils.ts`. Copy it from the
   reference:
   ```bash
   cp "${CLAUDE_PLUGIN_ROOT}/curriculum/reference/utils.ts" workspace/utils.ts
   ```
   If the file already exists and the learner hasn't edited it, overwrite it silently. If the learner
   has modified it, warn them and ask before overwriting.
   **The learner must NOT edit `workspace/utils.ts`** — it is provided scaffolding. They write only
   `workspace/agent.ts`.

3. **Node.js check:** verify Node 22+ is available — it runs `.ts` files natively.
   - `node --version` — should be v22 or higher.
   - `node -e "console.log(typeof fetch)"` — should print `function` (built-in fetch).
   - Note the Node version for the run command:
     - Node 22–23.5: learner must use `node --experimental-strip-types workspace/agent.ts`
     - Node 23.6+: learner can use `node workspace/agent.ts` (no flags needed)
   - No `npm install`. No `package.json`. No `tsx`. No transpiler.
   - Optional for IDE IntelliSense only: `npm i -D @types/node` (not required to run).

4. **Ollama check:** verify `ollama` is installed and running:
   - `ollama --version` (should show a version)
   - `curl http://localhost:11434/api/tags` (should list models, even if empty)
   - If no model is available, suggest: `ollama pull llama3:8b` (or any model the learner prefers — the dojo works with any Ollama model).
   - The suggested default is `llama3:8b` but ANY model works. Ask the learner which model they want to use and note it.

5. **Initial Modelfile:** create `workspace/Modelfile` with the base model and a simple SYSTEM prompt:
   ```
   FROM <model-name>
   SYSTEM You are a helpful assistant. Respond concisely.
   ```
   Replace `<model-name>` with the model the learner chose (or `llama3:8b` as default).
   Build it: `ollama create loopcraft -f workspace/Modelfile`

6. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (Ollama API reference, Modelfile format, Open-Meteo cheatsheet, DuckDuckGo cheatsheet, and INDEX.md).
   Confirm `./docs/INDEX.md` exists afterward.

7. **Tooling check:** verify
   - `node --version` (Node 22+ for native TypeScript),
   - `ollama list` (should show the model they pulled).

8. **Backend mode (which model backs Claude Code):** distinct from the Ollama model the *agent*
   calls (above) — this is the model the *tutor* runs on. Ask the learner: the **local-jailed**
   model (a local LLM served by **Ollama** or llama.cpp — a true air-gap, the default) or the
   **anthropic-api** easy-mode. For Ollama, pull a model (`ollama pull llama3:8b`; it listens on
   `:11434`) and launch with `--model llama3:8b` (the `loopcraft.sh` wrapper forwards it). Record the
   choice with `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.

9. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.loopcraft" && touch "${CLAUDE_PROJECT_DIR:-$PWD}/.loopcraft/.setup_done"`.
   (The SessionStart hook checks this sentinel — once it exists, opening Claude goes straight to
   tutoring instead of re-running setup.)

Report what's ready and what's missing, then move straight into **Step 1** (the SessionStart hook
already pointed you here; no need to wait for the learner to type `/loopcraft:start`).