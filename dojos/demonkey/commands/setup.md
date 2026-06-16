---
description: One-time setup — vendor the pinned gems, build the offline docs bundle, the memory-bench image, check tooling.
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will
build (their `workspace/` and `docs/` will live here). The day-to-day verification is local and
lightweight (`nc`, `ps`, `lsof`, `kill -SIGNAL`); the one exception is the **memory benchmark**
(`/demonkey:bench`, used at Steps 4 and 5 to show fork OOM vs preforking flat), which needs
**Docker** (the load generator is plain Ruby — no Go).

1. **Workspace:** create `./workspace/` if missing (the agent's only writable code dir).

2. **Gems for local runs — do this BEFORE any jailing, since it needs the network once.** The servers
   from Step 2 on `require 'protocol/http1'` and `'rack'`. Provision them so the learner can run
   `bundle exec ruby workspace/<server>.rb` locally:
   - copy the pinned `${CLAUDE_PLUGIN_ROOT}/env/bench/Gemfile` and
     `${CLAUDE_PLUGIN_ROOT}/env/bench/config.ru` to the project root,
   - vendor them: `bundle config set --local path vendor/bundle && bundle install`.

   After this, `bundle exec ruby -e "require 'protocol/http1'"` succeeds with no network. (Steps 1,
   4, 5, 6 are stdlib-only — `require 'socket'` — and need none of this; the gem requirement is for
   the HTTP steps, 2 and 7. The pinned set is just `rack`, `protocol-http1`, `protocol-http` — no
   async/falcon, because fibers are out of scope.)

3. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (ri dumps for Socket/Process/Signal, the man pages for fork/wait/sigaction/signal/kill/
   select, the protocol-http1 cheatsheet, the Rack spec, and INDEX.md). Confirm `./docs/INDEX.md`
   exists afterward.

4. **Tooling check (nothing to install on a typical macOS/Linux box):** verify
   - `ruby --version` (Ruby 3.x/4.x),
   - `nc -h` or `which nc` (BSD netcat — the test client),
   - `which lsof` and `which ps` (to inspect fds, the worker pool, and zombies),
   - `bundle --version` (for the HTTP steps).
   These cover the everyday local verification toolkit.

5. **Memory benchmark image (for `/demonkey:bench` at Steps 4–5):** this is the only part that
   needs **Docker**. Check `docker version`; if it's missing, note it and move on — the dojo still
   runs locally, only the OOM-vs-flat demo needs it. If present, build the target image up front so
   the first `/demonkey:bench` is fast:
   `docker build -t demonkey-target -f "${CLAUDE_PLUGIN_ROOT}/env/bench/Dockerfile.target" "${CLAUDE_PLUGIN_ROOT}/env/bench"`.
   The cage pins to one core (`--cpuset-cpus=0`) and a small memory budget (`--memory=192m
   --memory-swap=192m`); `env/bench/holder.rb` (plain stdlib Ruby) holds the idle connections that
   make fork's memory climb. No Go anywhere.

6. **Backend mode:** ask the learner whether they're running the **local-jailed** model
   (Ollama/llama.cpp, true air-gap — the default) or the **anthropic-api** easy-mode, and record it
   with `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.

7. **Mark setup done** so the auto-setup on future startups stays out of the way:
   `mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.demonkey" && touch "${CLAUDE_PROJECT_DIR:-$PWD}/.demonkey/.setup_done"`.
   (The SessionStart hook checks this sentinel — once it exists, opening Claude goes straight to
   tutoring instead of re-running setup.)

Report what's ready and what's missing, then move straight into **Step 1** (the SessionStart hook
already pointed you here; no need to wait for the learner to type `/demonkey:start`).
