---
description: One-time setup — provision dependencies offline-safe and build the docs bundle.
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will
build (their `workspace/` and `docs/` will live here).

1. **Workspace:** create `./workspace/` if missing (the agent's and learner's only writable code dir).
2. **Dependencies (do this BEFORE jailing — it needs the network once):**
   {{SETUP_DEPS}}
   After this the learner can run/build offline. The guard hook blocks ad-hoc installs afterward, so
   everything the curriculum needs must be vendored here.
3. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (reference material, cheatsheets, INDEX.md). Confirm `./docs/INDEX.md` exists afterward.
4. **Backend mode:** ask the learner whether they're running the **local-jailed** model (true
   air-gap — the default) or the **anthropic-api** easy-mode, and record it with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.
{{SETUP_EXTRA}}

Report what's ready and what's missing, then tell them to run `/{{PLUGIN_NAME}}:start`.
