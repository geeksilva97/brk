---
description: One-time setup — build the offline cheatsheet bundle (no dependencies to install).
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will work
(their per-project `.designme-daddy/` state will live here). This is a **no-code** dojo, so setup is
light: there is nothing to compile, vendor, or install — the only artifact is the offline cheatsheet
bundle the learner may consult during the interview.

1. **Dependencies:** none. This dojo is pure conversation — there is nothing to install. Skip straight
   to the docs bundle.

2. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (the latency-numbers, capacity-estimation, building-blocks, geospatial, and
   interview-framework cheatsheets, plus INDEX.md). Confirm `./docs/INDEX.md` exists afterward. This
   must run while the network is available — afterward the guard hook jails the session offline so the
   learner reasons from these cheatsheets and first principles.

3. **Tooling check:** nothing to verify — this dojo needs no runtime or tooling. Just confirm
   `./docs/INDEX.md` and the cheatsheets are present (`ls ./docs`).

4. **Backend mode:** ask the learner whether they're running the **local-jailed** model (true air-gap
   — the default) or the **anthropic-api** easy-mode, and record it with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.

5. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.designme-daddy" && touch "${CLAUDE_PROJECT_DIR:-$PWD}/.designme-daddy/.setup_done"`.
   (The SessionStart hook checks this sentinel — once it exists, opening Claude goes straight to
   tutoring instead of re-running setup.)

Report what's ready and what's missing, then move straight into **Step 1** (the SessionStart hook
already pointed you here; no need to wait for the learner to type `/designme-daddy:start`).
