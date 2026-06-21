---
description: One-time setup — build the offline docs bundle, the benchmark image, and check tooling.
---

Prepare the learner's project for the dojo. Run from the project directory where the learner will
build (their `workspace/` and `docs/` will live here).

1. **Workspace:** create `./workspace/` if missing (the agent's only writable code dir).
2. **Gems for local runs (do this BEFORE jailing — it needs the network once):** the servers from
   Step 2 on `require 'protocol/http1'`, `'rack'`, `'async'`, etc. Provision them so the learner can
   run `bundle exec ruby workspace/<server>.rb` locally:
   - copy the pinned `${CLAUDE_PLUGIN_ROOT}/env/bench/Gemfile` and
     `${CLAUDE_PLUGIN_ROOT}/env/bench/config.ru` to the project root,
   - vendor them offline-safe: `bundle config set --local path vendor/bundle && bundle install`.
   After this, `bundle exec ruby -e "require 'protocol/http1'"` succeeds with no network. (Step 1's
   echo is stdlib-only and needs none of this; the requirement starts at Step 2.)
3. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` — it generates
   `./docs/` (ri dumps, man pages, the protocol-http1 cheatsheet, the Rack spec, INDEX.md). Confirm
   `./docs/INDEX.md` exists afterward.
3. **Benchmark image + tools:** the harness uses **Docker + Go + `ab`** — all already present on a
   typical macOS/Linux box, nothing to install. Check Docker (`docker version`), Go (`go version`),
   and ApacheBench (`ab -V`; it ships at `/usr/sbin/ab` on macOS). Build the target image:
   `docker build -t c10k-target -f "${CLAUDE_PLUGIN_ROOT}/env/bench/Dockerfile.target" "${CLAUDE_PLUGIN_ROOT}/env/bench"`.
   `ab` measures throughput + latency; `env/bench/holder.go` (run with `go run`) measures
   held-connection capacity, which `ab` can't. The cage pins to one core (`--cpuset-cpus=0`).
4. **Backend mode (local model via Ollama):** ask which model backs Claude Code — the
   **local-jailed** model (a local LLM served by **Ollama** or llama.cpp — a true air-gap, the
   default) or the **anthropic-api** easy-mode. For Ollama, make sure it's serving the model
   (`ollama pull llama3:8b`; it listens on `:11434`) and launch with `--model llama3:8b` (the
   `c10k-dojo.sh` wrapper forwards it). Record the choice with
   `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" set-mode <local-jailed|anthropic-api>`.
5. **(Optional) ai-jail:** if they want OS-level isolation, point them at
   `${CLAUDE_PLUGIN_ROOT}/env/ai-jail.toml` as a template.

Report what's ready and what's missing, then tell them to run `/c10k-dojo:start`.
