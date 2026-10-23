---
description: One-time setup — vendor the sqlite3 gem, copy in the GIVEN baseline system, build the docs bundle.
---

Prepare the learner's project. Run from the project directory.

1. **Dependencies (BEFORE the jail closes — this is the one network step):**
   - Write a pinned `Gemfile` in the project root:
     ```
     source "https://rubygems.org"
     gem "sqlite3", "~> 2.0"
     ```
   - `bundle config set --local path vendor/bundle && bundle install`
   - Everything else is Ruby stdlib (`socket`, `json`, `timeout`, `fileutils`). Ruby ≥ 3.2 is
     required (the wire code uses `IO#timeout=`).

2. **The GIVEN baseline:** if `./workspace/` does not exist, copy the system as it stands after the
   earlier layers into it:
   `cp -R "${CLAUDE_PLUGIN_ROOT}/env/baseline" ./workspace && chmod +x ./workspace/bin/*`
   Never overwrite an existing `workspace/` — it holds the learner's decisions in code.
   Then `mkdir -p ./decisions`.

3. **Smoke test:** `./workspace/bin/cluster start && ./workspace/bin/cluster status && ./workspace/bin/cluster stop`.
   All three nodes (7001 leader, 7002 and 7003 followers) must answer. If a port is taken, say so.

4. **Offline docs bundle:** run `"${CLAUDE_PLUGIN_ROOT}/env/docs/build-bundle.sh"` and confirm
   `./docs/INDEX.md` exists.

5. **Mark setup done:** `touch "${CLAUDE_PROJECT_DIR:-$PWD}/.replicant-lead/.setup_done"`.

Tell the learner, briefly, what the GIVEN system is (point at `docs/baseline-cheatsheet.md`), then move
straight into the current step's incident.
