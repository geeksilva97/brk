# Contributing

## Adding a dojo

A dojo is just a Claude Code plugin directory. To make it appear in `brk list` / `brk run`:

1. Drop the plugin in `dojos/` (e.g. `dojos/my-dojo/`) with a valid
   `.claude-plugin/plugin.json`.
2. Add one line to `.claude-plugin/marketplace.json`:

   ```json
   { "name": "my-dojo", "source": "./dojos/my-dojo", "category": "workshop" }
   ```

   The `name` must match the plugin's own manifest `name` (a test enforces this).
3. `node --test` — the manifest-invariant tests check the entry resolves, the names match,
   and the plugin doesn't illegally declare a `hooks` field.

Don't hand-write a dojo from scratch — use the generator: `brk new "<your topic>"` runs
**dojo-forge**, which interviews you and scaffolds a complete, validating dojo in the right
shape (tutor skill, jail hooks, per-project state, curriculum). Then move it into `dojos/`
per the steps above.

See the README's **Creating a new dojo** section for full details on both forge-generated
and manual dojos.

## Running the tests

Zero dependencies — just Node ≥ 18:

```bash
node --test                              # the whole suite
node --test test/cli.test.js             # one file
node --test --experimental-test-coverage # with coverage
```

The suite never launches a real Claude session: a fake `claude` on `PATH`
(`test/helpers/claude-stub.cjs`) records the exact command the CLI builds, and every test
runs in an isolated temp `HOME`/XDG sandbox (`test/helpers/env.js`). The bash hook/state tests
(`guards`, `dojo-state`) are skipped on Windows.

There's an opt-in live tier that actually launches `claude -p` (needs auth + network):

```bash
BRK_LIVE=1 node --test test/live.test.js   # not part of CI
```

## Code shape

Plain ESM JavaScript, Node builtins only — no transpile, no bundler, no published package.
`bin/brk.js` → `src/cli.js` dispatches to `src/commands/*`; shared bits live in `src/lib/`
(`claude.js` spawns Claude, `git.js` fetches registries, `marketplace.js` parses manifests).
Keep it dependency-free.