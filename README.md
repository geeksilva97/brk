# dojos

Tutored, constrained **coding-dojo plugins for Claude Code** — build real systems the hard
way, with a Socratic tutor that makes you type the load-bearing code yourself and an offline
jail that keeps you honest.

The `dojo` CLI lets you **start a dojo right away** or **install it** for use in any session.
Nothing is published anywhere — the tool runs straight from this clone.

## Install the CLI

You need `git`, `node` ≥ 18, and the `claude` CLI on your PATH.

```bash
gh repo clone geeksilva97/dojos ~/.dojos && ~/.dojos/install.sh
```

`install.sh` symlinks `dojo` onto your PATH (`~/.local/bin` by default) and tells you if that
dir isn't on your PATH yet. Re-run it any time to update (it `git pull`s and re-links).

## Use it

```bash
dojo list                          # what's available
dojo run demonkey ./my-workshop    # start now, in ./my-workshop — nothing installed
dojo install demonkey              # persistent: /demonkey:start works in any claude session
dojo update                        # pull the latest tool + dojos
```

- **`dojo run`** is the quickest way in: it launches Claude with the dojo loaded, offline jail
  on, in the project dir you name (created if needed). Close it and nothing lingers.
- **`dojo install`** registers the dojo as a native Claude Code plugin, so its slash commands
  (e.g. `/demonkey:start`) are available everywhere until you `dojo uninstall` it.

## The dojos

| Dojo | What you build |
|------|----------------|
| **demonkey** | Ruby web servers through the process family — raw socket → Unicorn-like preforking server with signals, graceful shutdown, USR2 restart. |
| **c10k-dojo** | Ruby web servers from raw sockets to C10K, graded against a constrained benchmark. |
| **reactor-dojo** | A single-threaded `IO.select` reactor that juggles thousands of connections. |
| **dojo-forge** | The generator: scaffold a brand-new dojo for any topic (`dojo new`). |

## Offline by design

Each dojo runs in a jail (a `WebFetch`/`WebSearch` block plus the plugin's own guard hooks),
so you work from a bundled docs bundle, not the internet. That's the point — the friction is
the lesson. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how it all fits together,
and [`CONTRIBUTING.md`](CONTRIBUTING.md) to add your own dojo.
