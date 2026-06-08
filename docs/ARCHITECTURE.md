# Architecture

The `dojo` CLI is a thin front-end over Claude Code's native plugin system. It adds the one
thing Claude Code lacks — a *run-right-away* path for plugins — and a registry model that
scales beyond this repo. No backend, no database, nothing published.

## Two flows, mapped to Claude Code

- **`dojo run <name>`** (ephemeral). `--plugin-dir`/`--plugin-url` only accept local paths or
  `.zip` archives, never git URLs — so the CLI resolves a dojo to an on-disk directory, then
  spawns `claude --plugin-dir <dir>` with the uniform learner-dojo flags (offline jail on,
  prompt suggestions off). Nothing is written to `~/.claude/plugins`.
- **`dojo install <name>`** (persistent). Wraps the native `claude plugin marketplace add` +
  `claude plugin install <name>@<marketplace>`. From then on the dojo's slash commands work in
  any session until `dojo uninstall`.

## Registry-agnostic resolution

A **registry** is a git repo (or local dir) containing a `.claude-plugin/marketplace.json`.

- The **self registry** is this repo — it's already on disk next to the CLI, so the bundled
  dojos resolve with zero network.
- **Extra registries** live in `~/.config/dojo/registries` (one `git-url [name]` per line,
  managed by `dojo registry add/list/remove`). They're cloned/pulled into `~/.cache/dojo/<name>/`
  on demand.

`resolveDojo(name)` checks local registries first, then git ones; the first marketplace entry
whose `name` matches wins, and its `source` (a relative path) gives the plugin dir. Listing and
parsing is plain `JSON.parse` — no jq.

This is the **scale hook**: any org publishes a `dojos`-shaped repo, and consumers
`dojo registry add <org>/<repo>` to run/install its dojos. Going broad later (public repos,
or even publishing the CLI) is additive — it rides Claude Code marketplaces + git, no migration.

## The jail (enforced by each dojo, not the CLI)

Every learner dojo ships the same invariants — the CLI only sets the belt-and-suspenders
`--disallowed-tools WebSearch WebFetch` at launch; the real enforcement is inside the plugin:

- **No `hooks` field in `plugin.json`** — hooks auto-load from `hooks/hooks.json` (a duplicate
  declaration errors). A test guards this.
- **Per-project state** in `<project>/.<dojo>/progress.json` — a new folder starts at step 1.
- **Type-the-spine guard** — a `PreToolUse` hook denies the agent writing the current step's
  spine file (the lines that *are* the lesson); glue files are fine.
- **Offline guard** — denies `WebFetch`/`WebSearch`, external Bash egress (localhost allowed),
  and ad-hoc dependency installs. Work from the bundled docs.

## Layout

```
bin/dojo.js          entry (the file install.sh symlinks)
src/cli.js           command dispatch
src/registry.js      registry config + resolution
src/commands/*.js    run, install, list, update, registry, new, help
src/lib/*.js         claude (spawn), git (fetch), marketplace (JSON), paths (XDG)
<dojo>/              each bundled dojo plugin (demonkey, c10k-dojo, dojo-forge, …)
.claude-plugin/marketplace.json   the self registry's catalog
```
