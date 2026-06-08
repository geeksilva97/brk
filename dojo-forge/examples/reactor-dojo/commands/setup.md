---
description: One-time setup — build the offline docs bundle and check tooling (stdlib-only, no deps).
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will
build (their `workspace/` and `docs/` will live here).

1. **Workspace:** create `./workspace/` if missing (the agent's and learner's only writable code dir).
2. **Dependencies (do this BEFORE jailing — it needs the network once):**
   This dojo is **stdlib-only**. The reactor is built from Ruby's `Socket`/`TCPServer` and
   `IO.select` — nothing to install, no Gemfile, no bundle. Just confirm Ruby is present:
   `ruby -v` (Ruby 3.x+). After this the learner can run everything offline.
3. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (ri dumps for IO/Socket/TCPServer, the select/kqueue man pages, the reactor cheatsheet,
   INDEX.md). Confirm `./docs/INDEX.md` exists afterward.
4. **Backend mode:** ask the learner whether they're running the **local-jailed** model (true
   air-gap — the default) or the **anthropic-api** easy-mode, and record it with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.

Report what's ready and what's missing, then tell them to run `/reactor-dojo:start`.
