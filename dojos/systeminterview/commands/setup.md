---
description: "One-time setup for the System Design Interview dojo"
---

One-time setup — prepare the learner's project for the dojo. Run from the project directory where
the learner will build (their `workspace/` will live here).

1. **Workspace:** create `./workspace/` if missing (the learner's only writable doc dir).

2. **Dependencies:** No external dependencies needed for this dojo — it's a design interview, not
   a coding exercise. The candidate writes design documents, not code.

3. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (reference material, cheatsheets, INDEX.md). Confirm `./docs/INDEX.md` exists afterward.

4. **Backend mode:** ask the learner whether they're running the **local-jailed** model (true
   air-gap — the default) or the **anthropic-api** easy-mode, and record it with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.

5. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview" && touch "${CLAUDE_PROJECT_DIR:-$PWD}/.systeminterview/.setup_done"`.
   (The SessionStart hook checks this sentinel — once it exists, opening Claude goes straight to
   tutoring instead of re-running setup.)

Report what's ready and what's missing, then move straight into **Step 1** (the SessionStart hook
already pointed you here; no need to wait for the learner to type `/systeminterview:start`).